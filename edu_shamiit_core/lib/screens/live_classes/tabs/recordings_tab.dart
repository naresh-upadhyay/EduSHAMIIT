import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:edu_shamiit_core/utils/download_helper.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';
import '../utils/live_class_theme.dart';
import '../widgets/live_class_stat_card.dart';
import '../widgets/upload_recording_dialog.dart';
import '../widgets/auto_recording_rules_dialog.dart';
import '../widgets/recording_player_widget.dart';
import '../widgets/recording_edit_dialog.dart';
import '../widgets/recording_share_dialog.dart';

class RecordingsTab extends ConsumerStatefulWidget {
  const RecordingsTab({super.key});

  @override
  ConsumerState<RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends ConsumerState<RecordingsTab> {
  String _selectedScope = 'All Recordings';
  String _dateFilter = 'All Dates';
  String _typeFilter = 'All Types';
  String _visibilityFilter = 'All Visibility';
  RecordingItem? _selectedRecording;
  final Set<String> _selectedIds = {};
  final Map<String, String> _resolvedStreamUrls = {};
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();

  // Settings state (synced from backend dashboard.settings)
  bool _settingsSynced = false;
  bool _autoRecording = true;
  bool _cloudStorage = true;
  String _retentionPeriod = '180 Days';
  String _recordingQuality = 'HD (720p)';
  bool _allowStudentDownload = true;
  bool _isSavingSettings = false;

  // Theme helper getters
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get cardBg => isDark ? const Color(0xFF13182C) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);
  Color get cardDivider => isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get headerRowBg => isDark ? const Color(0xFF1A2238) : const Color(0xFFF8FAFC);
  Color get inputBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get selectedRowBg => isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureStreamUrl(RecordingItem item) async {
    if (_resolvedStreamUrls.containsKey(item.id)) return;
    final api = ref.read(liveClassApiServiceProvider);
    final url = await api.resolveAuthenticatedMediaUrl(item);
    if (!mounted) return;
    setState(() => _resolvedStreamUrls[item.id] = url);
  }

  Future<void> _openFullscreenPlayer(RecordingItem item) async {
    final api = ref.read(liveClassApiServiceProvider);
    final url = _resolvedStreamUrls[item.id] ?? await api.resolveAuthenticatedMediaUrl(item);
    if (!mounted) return;
    setState(() => _resolvedStreamUrls[item.id] = url);
    await RecordingFullscreenDialog.show(
      context,
      item: item,
      resolvedUrl: url,
      onFirstPlay: () => ref.read(liveClassManagementProvider.notifier).trackRecordingView(item.id),
      onDownload: () => _downloadRecording(item),
    );
  }

  Future<void> _downloadRecording(RecordingItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Downloading "${item.title}"...'),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      final api = ref.read(liveClassApiServiceProvider);
      final url = await api.resolveAuthenticatedMediaUrl(item, isDownload: true);
      final cleanName = item.title
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]+'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final filename = '${cleanName.isNotEmpty ? cleanName : 'recording'}.mp4';
      await getDownloadHelper().downloadFile(url, filename);
      await ref.read(liveClassManagementProvider.notifier).refreshRecordings(selectRecordingId: item.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Downloaded "$filename"'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Download unavailable: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showShareDialog(RecordingItem item) {
    RecordingShareDialog.show(context, item);
  }

  void _showEditDialog(RecordingItem item) async {
    await RecordingEditDialog.show(context, item);
  }

  void _showDetailsDialog(RecordingItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.school_outlined, 'Class / Section', item.classSection),
              _buildDetailRow(Icons.menu_book_outlined, 'Subject', item.subjectName),
              _buildDetailRow(Icons.person_outline_rounded, 'Instructor', item.teacherName),
              _buildDetailRow(Icons.calendar_today_rounded, 'Recorded On', item.dateTimeStr),
              _buildDetailRow(Icons.schedule_rounded, 'Duration', item.durationStr),
              _buildDetailRow(Icons.storage_rounded, 'File Size', item.sizeStr),
              _buildDetailRow(Icons.visibility_outlined, 'Views / Downloads', '${item.views} views • ${item.downloadsCount} downloads'),
              _buildDetailRow(Icons.share_outlined, 'Shared With', '${item.sharedCount} group/user share(s)'),
              if ((item.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Lesson Summary & Notes', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 4),
                Text(item.description!, style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditDialog(item);
            },
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('Edit'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openFullscreenPlayer(item);
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Play Video'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRecording(RecordingItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Delete Recording?', style: TextStyle(color: textPrimary)),
        content: Text(
          'This will permanently remove "${item.title}" from recordings & storage.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(liveClassManagementProvider.notifier).deleteRecording(item.id);
              if (mounted) {
                setState(() {
                  _selectedIds.remove(item.id);
                  if (_selectedRecording?.id == item.id) _selectedRecording = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Recording "${item.title}" deleted.' : 'Failed to delete recording.'),
                    backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _persistSettings({
    bool? autoRecording,
    bool? cloudStorage,
    String? retentionPeriod,
    String? recordingQuality,
    bool? allowStudentDownload,
  }) async {
    setState(() {
      if (autoRecording != null) _autoRecording = autoRecording;
      if (cloudStorage != null) _cloudStorage = cloudStorage;
      if (retentionPeriod != null) _retentionPeriod = retentionPeriod;
      if (recordingQuality != null) _recordingQuality = recordingQuality;
      if (allowStudentDownload != null) _allowStudentDownload = allowStudentDownload;
      _isSavingSettings = true;
    });

    final days = int.tryParse(RegExp(r'\d+').firstMatch(_retentionPeriod)?.group(0) ?? '180') ?? 3650;
    final ok = await ref.read(liveClassManagementProvider.notifier).saveRecordingSettings(
      autoRecording: _autoRecording,
      cloudStorage: _cloudStorage,
      defaultRetentionDays: days,
      recordingQuality: _recordingQuality,
      allowStudentDownload: _allowStudentDownload,
    );
    if (!mounted) return;
    setState(() => _isSavingSettings = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Recording settings saved.' : 'Could not save settings.'),
        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveClassManagementProvider);
    final dashboard = state.recordingsDashboard;
    final recordings = state.recordings;

    if (!_settingsSynced && dashboard != null) {
      _settingsSynced = true;
      _autoRecording = dashboard.settings.autoRecording;
      _cloudStorage = dashboard.settings.cloudStorage;
      _allowStudentDownload = dashboard.settings.allowStudentDownload;
      _recordingQuality = dashboard.settings.recordingQuality;
      final d = dashboard.settings.defaultRetentionDays;
      _retentionPeriod = d >= 3650 ? 'Unlimited' : (d == 365 ? '365 Days' : (d == 90 ? '90 Days' : '180 Days'));
    }

    RecordingItem? currentSelected;
    if (_selectedRecording != null) {
      currentSelected = recordings.where((r) => r.id == _selectedRecording!.id).firstOrNull;
    }
    currentSelected ??= state.selectedRecordingForPreview != null
        ? (recordings.where((r) => r.id == state.selectedRecordingForPreview!.id).firstOrNull ?? state.selectedRecordingForPreview)
        : (recordings.isNotEmpty ? recordings.first : null);

    if (currentSelected != null && !_resolvedStreamUrls.containsKey(currentSelected.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && currentSelected != null) {
          _ensureStreamUrl(currentSelected);
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top KPI Row (7 Cards matching Image 2)
          _buildKpiRow(dashboard),
          const SizedBox(height: 16),

          // 2. Middle Main Workspace (Recordings Table + Preview & Details - Left Nav removed)
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 1180;
              final isMedium = constraints.maxWidth < 1450;

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRecordingsTableSection(recordings, state, currentSelected),
                    const SizedBox(height: 16),
                    _buildPreviewAndDetailsSection(currentSelected),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildRecordingsTableSection(recordings, state, currentSelected),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: isMedium ? 5 : 4,
                    child: _buildPreviewAndDetailsSection(currentSelected),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. Bottom Row: Analytics Chart, Storage Usage, Recording Settings
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 950) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnalyticsChartCard(dashboard?.analytics30Days ?? const []),
                    const SizedBox(height: 12),
                    _buildStorageUsageCard(dashboard),
                    const SizedBox(height: 12),
                    _buildRecordingSettingsCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildAnalyticsChartCard(dashboard?.analytics30Days ?? const []),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildStorageUsageCard(dashboard),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildRecordingSettingsCard(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }



  Widget _buildKpiRow(RecordingsDashboardData? data) {
    final totalRecStr = '${data?.totalRecordings ?? 0}';
    final thisWeekStr = '${data?.thisWeek ?? 0}';
    final totalDurStr = data?.totalDurationDisplay ?? '0 min';
    final storageStr = '${(data?.storageUsedGb ?? 0).toStringAsFixed(2)} GB';
    final storagePctStr = '(${data?.storageUsedPercentage ?? 0}%)';
    final downloadsStr = '${data?.totalDownloads ?? 0}';
    final avgViewsStr = '${data?.avgViews ?? 0}';
    final retentionStr = '${data?.retentionRatePct ?? 100}%';

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1500) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 185,
                  child: LiveClassStatCard(
                    title: 'Total Recordings',
                    value: totalRecStr,
                    icon: Icons.video_library_rounded,
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 175,
                  child: LiveClassStatCard(
                    title: 'This Week',
                    value: thisWeekStr,
                    icon: Icons.play_circle_fill_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 190,
                  child: LiveClassStatCard(
                    title: 'Total Duration',
                    value: totalDurStr,
                    icon: Icons.schedule_rounded,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 205,
                  child: LiveClassStatCard(
                    title: 'Storage Used',
                    value: storageStr,
                    subtitle: storagePctStr,
                    icon: Icons.cloud_done_rounded,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 185,
                  child: LiveClassStatCard(
                    title: 'Total Downloads',
                    value: downloadsStr,
                    icon: Icons.file_download_outlined,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 195,
                  child: LiveClassStatCard(
                    title: 'Avg. Views / Recording',
                    value: avgViewsStr,
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 175,
                  child: LiveClassStatCard(
                    title: 'Retention Rate',
                    value: retentionStr,
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          );
        }
        return Row(
          children: [
            Expanded(
              child: LiveClassStatCard(
                title: 'Total Recordings',
                value: totalRecStr,
                icon: Icons.video_library_rounded,
                iconColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'This Week',
                value: thisWeekStr,
                icon: Icons.play_circle_fill_rounded,
                iconColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Total Duration',
                value: totalDurStr,
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Storage Used',
                value: storageStr,
                subtitle: storagePctStr,
                icon: Icons.cloud_done_rounded,
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Total Downloads',
                value: downloadsStr,
                icon: Icons.file_download_outlined,
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Avg. Views / Recording',
                value: avgViewsStr,
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Retention Rate',
                value: retentionStr,
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAudienceBadge(String visibility, bool isDark) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    final upper = visibility.toUpperCase();
    if (upper == 'SCHOOL' || upper == 'SHARED') {
      bg = isDark ? const Color(0xFF312E81).withValues(alpha: 0.6) : const Color(0xFFEEF2FF);
      fg = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5);
      icon = Icons.domain_rounded;
      label = 'Entire School';
    } else if (upper == 'PRIVATE') {
      bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7);
      fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706);
      icon = Icons.lock_outline_rounded;
      label = 'Private';
    } else {
      // Default: CLASS
      bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF);
      fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);
      icon = Icons.group_outlined;
      label = 'Class Only';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: fg),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopePill(String title, IconData icon) {
    final isSelected = _selectedScope == title;
    return InkWell(
      onTap: () {
        setState(() => _selectedScope = title);
      },
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingsTableSection(
    List<RecordingItem> recordings,
    LiveClassState state,
    RecordingItem? currentSelected,
  ) {
    final meta = state.dropdownMeta;
    final classes = meta?.classes ?? [];
    final subjects = meta?.subjects ?? [];

    final filteredRecordings = recordings.where((rec) {
      if (_selectedScope == 'Shared') {
        if (!rec.tags.contains('shared') &&
            rec.sharedCount <= 0 &&
            rec.visibility.toUpperCase() != 'SHARED' &&
            rec.visibility.toUpperCase() != 'SCHOOL') {
          return false;
        }
      } else if (_selectedScope == 'Requests') {
        if (rec.status.toLowerCase() != 'requested' && rec.status.toLowerCase() != 'pending') {
          return false;
        }
      }

      if (_typeFilter == 'Auto (Live Class)') {
        if (rec.type.toLowerCase().contains('upload') || rec.tags.contains('upload')) return false;
      } else if (_typeFilter == 'Uploaded') {
        if (!rec.type.toLowerCase().contains('upload') && !rec.tags.contains('upload')) return false;
      }

      if (_visibilityFilter == 'Class Enrolled Only') {
        if (rec.visibility.toUpperCase() != 'CLASS') return false;
      } else if (_visibilityFilter == 'Entire School') {
        if (rec.visibility.toUpperCase() != 'SCHOOL' && rec.visibility.toUpperCase() != 'SHARED') return false;
      } else if (_visibilityFilter == 'Private (Teachers)') {
        if (rec.visibility.toUpperCase() != 'PRIVATE') return false;
      }

      if (_dateFilter != 'All Dates') {
        final now = DateTime.now();
        const months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};
        final parts = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})').firstMatch(rec.dateTimeStr.trim());
        if (parts != null) {
          final d = int.tryParse(parts.group(1)!) ?? now.day;
          final m = months[parts.group(2)!.toLowerCase()] ?? now.month;
          final y = int.tryParse(parts.group(3)!) ?? now.year;
          final recDate = DateTime(y, m, d);
          final diffDays = now.difference(recDate).inDays;
          if (_dateFilter == 'Today' && diffDays > 0) return false;
          if (_dateFilter == 'This Week' && diffDays > 7) return false;
          if (_dateFilter == 'This Month' && (recDate.month != now.month || recDate.year != now.year)) return false;
        }
      }

      if (_searchCtrl.text.trim().isNotEmpty) {
        final q = _searchCtrl.text.trim().toLowerCase();
        final match = rec.title.toLowerCase().contains(q) ||
            rec.classSection.toLowerCase().contains(q) ||
            rec.subjectName.toLowerCase().contains(q) ||
            rec.teacherName.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header: Scope Selector Pills + Two Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    // Scope Selector Pills
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: cardBorder),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildScopePill('My Recordings', Icons.video_library_rounded),
                            _buildScopePill('All Recordings', Icons.grid_view_rounded),
                            _buildScopePill('Shared', Icons.share_rounded),
                            _buildScopePill('Requests', Icons.assignment_turned_in_rounded),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons Row: [ ⚙️ Auto Recording Rules ] and [ + Upload Recording ]
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Auto Recording Rules Button
                        OutlinedButton.icon(
                          onPressed: () => AutoRecordingRulesDialog.show(context),
                          icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF3B82F6)),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Flexible(
                                child: Text(
                                  'Auto Recording Rules',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                                ),
                              ),
                              if (state.autoRecordingRules.hasActiveRules) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                                  ),
                                  child: const Text('Active', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ),
                              ],
                            ],
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),

                        // Upload Recording Button
                        ElevatedButton.icon(
                          onPressed: () => UploadRecordingDialog.show(context),
                          icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                          label: const Text(
                            'Upload Recording',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: cardDivider),

          // Filters Toolbar Row (Compact & Space-Efficient)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.45) : const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: cardBorder)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterDropdown(
                  value: classes.where((c) => c.id == state.recordingClassFilter).firstOrNull?.name ?? 'All Classes',
                  items: ['All Classes', ...classes.map((e) => e.name)],
                  width: 125,
                  onChanged: (v) {
                    if (v == null || v == 'All Classes') {
                      ref.read(liveClassManagementProvider.notifier).setRecordingsClassFilter(null);
                    } else {
                      final match = classes.where((c) => c.name == v).firstOrNull;
                      ref.read(liveClassManagementProvider.notifier).setRecordingsClassFilter(match?.id ?? v);
                    }
                  },
                ),
                _buildFilterDropdown(
                  value: subjects.where((s) => s.id == state.recordingSubjectFilter).firstOrNull?.name ?? 'All Subjects',
                  items: ['All Subjects', ...subjects.map((e) => e.name)],
                  width: 130,
                  onChanged: (v) {
                    if (v == null || v == 'All Subjects') {
                      ref.read(liveClassManagementProvider.notifier).setRecordingsSubjectFilter(null);
                    } else {
                      final match = subjects.where((s) => s.name == v).firstOrNull;
                      ref.read(liveClassManagementProvider.notifier).setRecordingsSubjectFilter(match?.id ?? v);
                    }
                  },
                ),
                _buildFilterDropdown(
                  value: (meta?.teachers ?? []).where((t) => t.id == state.recordingTeacherFilter).firstOrNull?.name ?? 'All Teachers',
                  items: ['All Teachers', ...(meta?.teachers.map((t) => t.name) ?? ['R. Kumar', 'P. Sharma', 'A. Gupta', 'King Doe'])],
                  width: 125,
                  onChanged: (v) {
                    if (v == null || v == 'All Teachers') {
                      ref.read(liveClassManagementProvider.notifier).setRecordingsTeacherFilter(null);
                    } else {
                      final match = meta?.teachers.where((t) => t.name == v).firstOrNull;
                      ref.read(liveClassManagementProvider.notifier).setRecordingsTeacherFilter(match?.id ?? v);
                    }
                  },
                ),
                _buildFilterDropdown(
                  value: _dateFilter,
                  items: const ['All Dates', 'Today', 'This Week', 'This Month'],
                  width: 110,
                  onChanged: (v) {
                    if (v != null) setState(() => _dateFilter = v);
                  },
                ),
                _buildFilterDropdown(
                  value: _typeFilter,
                  items: const ['All Types', 'Auto (Live Class)', 'Uploaded'],
                  width: 125,
                  onChanged: (v) {
                    if (v != null) setState(() => _typeFilter = v);
                  },
                ),
                _buildFilterDropdown(
                  value: _visibilityFilter,
                  items: const ['All Visibility', 'Class Enrolled Only', 'Entire School', 'Private (Teachers)'],
                  width: 140,
                  onChanged: (v) {
                    if (v != null) setState(() => _visibilityFilter = v);
                  },
                ),
                SizedBox(
                  width: 180,
                  height: 32,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      setState(() {});
                      ref.read(liveClassManagementProvider.notifier).setRecordingsSearch(v);
                    },
                    style: TextStyle(fontSize: 11, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search recordings...',
                      hintStyle: TextStyle(fontSize: 11, color: textSecondary),
                      prefixIcon: Icon(Icons.search, size: 14, color: textSecondary),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                    ),
                  ),
                ),
                if (state.recordingClassFilter != null ||
                    state.recordingSubjectFilter != null ||
                    state.recordingTeacherFilter != null ||
                    _dateFilter != 'All Dates' ||
                    _typeFilter != 'All Types' ||
                    _visibilityFilter != 'All Visibility' ||
                    _searchCtrl.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _dateFilter = 'All Dates';
                        _typeFilter = 'All Types';
                        _visibilityFilter = 'All Visibility';
                        _searchCtrl.clear();
                      });
                      ref.read(liveClassManagementProvider.notifier).setRecordingsClassFilter(null);
                      ref.read(liveClassManagementProvider.notifier).setRecordingsSubjectFilter(null);
                      ref.read(liveClassManagementProvider.notifier).setRecordingsTeacherFilter(null);
                      ref.read(liveClassManagementProvider.notifier).setRecordingsSearch('');
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.clear_rounded, size: 13, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          if (_selectedIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedIds.length} recording(s) selected',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    child: const Text('Clear Selection', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ids = _selectedIds.toList();
                      final count = await ref.read(liveClassManagementProvider.notifier).bulkDeleteRecordings(ids);
                      if (!mounted) return;
                      setState(() => _selectedIds.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deleted $count selected recording(s).'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Delete Selected', style: TextStyle(fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          if (filteredRecordings.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library_outlined, size: 48, color: textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'No recordings found matching your current filter',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedScope = 'All Recordings';
                        _dateFilter = 'All Dates';
                        _typeFilter = 'All Types';
                        _visibilityFilter = 'All Visibility';
                        _searchCtrl.clear();
                      });
                      ref.read(liveClassManagementProvider.notifier).setRecordingsClassFilter(null);
                      ref.read(liveClassManagementProvider.notifier).setRecordingsSubjectFilter(null);
                      ref.read(liveClassManagementProvider.notifier).setRecordingsTeacherFilter(null);
                      ref.read(liveClassManagementProvider.notifier).setRecordingsSearch('');
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Reset All Filters', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Scrollable Table Area with Responsive Dynamic Width & Scrollbar
            LayoutBuilder(
              builder: (context, tableConstraints) {
                const minTableWidth = 1095.0;
                final tableWidth = math.max(tableConstraints.maxWidth, minTableWidth);
                final extraWidth = math.max(0.0, tableWidth - minTableWidth);
                final titleWidth = 210.0 + extraWidth;

                return Scrollbar(
                  controller: _tableScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: headerRowBg,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        final allVisibleSelected = filteredRecordings.isNotEmpty &&
                                            filteredRecordings.every((r) => _selectedIds.contains(r.id));
                                        if (allVisibleSelected) {
                                          for (final r in filteredRecordings) {
                                            _selectedIds.remove(r.id);
                                          }
                                        } else {
                                          for (final r in filteredRecordings) {
                                            _selectedIds.add(r.id);
                                          }
                                        }
                                      });
                                    },
                                    child: Icon(
                                      (filteredRecordings.isNotEmpty && filteredRecordings.every((r) => _selectedIds.contains(r.id)))
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank,
                                      size: 16,
                                      color: (filteredRecordings.isNotEmpty && filteredRecordings.every((r) => _selectedIds.contains(r.id)))
                                          ? const Color(0xFF3B82F6)
                                          : textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(width: titleWidth, child: Text('Recording Title', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 95, child: Text('Class / Section', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 100, child: Text('Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 130, child: Text('Date & Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 65, child: Text('Duration', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 50, child: Text('Views', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 60, child: Text('Size', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 90, child: Text('Audience', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 70, child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                const SizedBox(width: 8),
                                SizedBox(width: 65, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: cardBorder),

                          // Table Rows
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredRecordings.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: cardDivider),
                            itemBuilder: (context, index) {
                              final rec = filteredRecordings[index];
                              final isSelected = currentSelected?.id == rec.id;

                              return InkWell(
                                onTap: () {
                                  setState(() => _selectedRecording = rec);
                                },
                                child: Container(
                                  color: isSelected ? selectedRowBg : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (_selectedIds.contains(rec.id)) {
                                                _selectedIds.remove(rec.id);
                                              } else {
                                                _selectedIds.add(rec.id);
                                              }
                                            });
                                          },
                                          child: Icon(
                                            _selectedIds.contains(rec.id)
                                                ? Icons.check_box_rounded
                                                : Icons.check_box_outline_blank,
                                            size: 16,
                                            color: _selectedIds.contains(rec.id)
                                                ? const Color(0xFF3B82F6)
                                                : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Title with Play Icon
                                      SizedBox(
                                        width: titleWidth,
                                        child: Row(
                                          children: [
                                            const Icon(Icons.play_circle_fill_rounded, size: 16, color: Color(0xFF2563EB)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                rec.title,
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(width: 95, child: Text(rec.classSection, style: TextStyle(fontSize: 11, color: textSecondary), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      SizedBox(width: 100, child: Text(rec.subjectName, style: TextStyle(fontSize: 11, color: textSecondary), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          rec.dateTimeStr,
                                          style: TextStyle(fontSize: 10, color: textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(width: 65, child: Text(rec.durationStr, style: TextStyle(fontSize: 11, color: textSecondary))),
                                      const SizedBox(width: 8),
                                      SizedBox(width: 50, child: Text('${rec.views}', style: TextStyle(fontSize: 11, color: textSecondary))),
                                      const SizedBox(width: 8),
                                      SizedBox(width: 60, child: Text(rec.sizeStr, style: TextStyle(fontSize: 11, color: textSecondary))),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 90,
                                        child: _buildAudienceBadge(rec.visibility, isDark),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 70,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            rec.status,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 65,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            InkWell(
                                              onTap: () => _downloadRecording(rec),
                                              child: const Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF2563EB)),
                                            ),
                                            const SizedBox(width: 4),
                                            SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: PopupMenuButton<String>(
                                                icon: Icon(Icons.more_vert, size: 16, color: textSecondary),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onSelected: (val) {
                                                  if (val == 'play') {
                                                    setState(() => _selectedRecording = rec);
                                                    _openFullscreenPlayer(rec);
                                                  } else if (val == 'share') {
                                                    _showShareDialog(rec);
                                                  } else if (val == 'edit') {
                                                    _showEditDialog(rec);
                                                  } else if (val == 'download') {
                                                    _downloadRecording(rec);
                                                  } else if (val == 'details') {
                                                    _showDetailsDialog(rec);
                                                  } else if (val == 'delete') {
                                                    _confirmDeleteRecording(rec);
                                                  }
                                                },
                                                itemBuilder: (ctx) => [
                                                  const PopupMenuItem(value: 'play', child: Text('Play Fullscreen', style: TextStyle(fontSize: 12))),
                                                  const PopupMenuItem(value: 'share', child: Text('Share Recording', style: TextStyle(fontSize: 12))),
                                                  const PopupMenuItem(value: 'edit', child: Text('Edit Details', style: TextStyle(fontSize: 12))),
                                                  const PopupMenuItem(value: 'download', child: Text('Download Video', style: TextStyle(fontSize: 12))),
                                                  const PopupMenuItem(value: 'details', child: Text('View Details', style: TextStyle(fontSize: 12))),
                                                  const PopupMenuItem(value: 'delete', child: Text('Delete Recording', style: TextStyle(fontSize: 12, color: Colors.red))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          // Pagination Footer (Responsive for Mobile / Tablet / Desktop)
          LayoutBuilder(
            builder: (context, footerConstraints) {
              final isNarrow = footerConstraints.maxWidth < 680;

              if (isNarrow) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: cardBorder)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Showing 1 - ${recordings.length} of ${state.recordingsTotalCount} recordings',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildPageButton(
                              '<',
                              false,
                              onTap: state.recordingsPage > 1
                                  ? () => ref.read(liveClassManagementProvider.notifier).setRecordingsPage(state.recordingsPage - 1)
                                  : null,
                            ),
                            for (int p = 1; p <= math.min(state.recordingsTotalPages, 5); p++)
                              _buildPageButton(
                                '$p',
                                p == state.recordingsPage,
                                onTap: () => ref.read(liveClassManagementProvider.notifier).setRecordingsPage(p),
                              ),
                            if (state.recordingsTotalPages > 5) ...[
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('...', style: TextStyle(color: textSecondary))),
                              _buildPageButton(
                                '${state.recordingsTotalPages}',
                                state.recordingsPage == state.recordingsTotalPages,
                                onTap: () => ref.read(liveClassManagementProvider.notifier).setRecordingsPage(state.recordingsTotalPages),
                              ),
                            ],
                            _buildPageButton(
                              '>',
                              false,
                              onTap: state.recordingsPage < state.recordingsTotalPages
                                  ? () => ref.read(liveClassManagementProvider.notifier).setRecordingsPage(state.recordingsPage + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cardBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing 1 - ${recordings.length} of ${state.recordingsTotalCount} recordings',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                    Row(
                      children: [
                        _buildPageButton(
                          '<',
                          false,
                          onTap: state.recordingsPage > 1
                              ? () => ref.read(liveClassManagementProvider.notifier).setRecordingsPage(state.recordingsPage - 1)
                              : null,
                        ),
                        for (int p = 1; p <= math.min(state.recordingsTotalPages, 5); p++)
                          _buildPageButton(
                            '$p',
                            p == state.recordingsPage,
                            onTap: () => ref.read(liveClassManagementProvider.notifier).setRecordingsPage(p),
                          ),
                        if (state.recordingsTotalPages > 5) ...[
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('...', style: TextStyle(color: textSecondary))),
                          _buildPageButton(
                            '${state.recordingsTotalPages}',
                            state.recordingsPage == state.recordingsTotalPages,
                            onTap: () => ref.read(liveClassManagementProvider.notifier).setRecordingsPage(state.recordingsTotalPages),
                          ),
                        ],
                        _buildPageButton(
                          '>',
                          false,
                          onTap: state.recordingsPage < state.recordingsTotalPages
                              ? () => ref.read(liveClassManagementProvider.notifier).setRecordingsPage(state.recordingsPage + 1)
                              : null,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Rows per page:', style: TextStyle(fontSize: 11, color: textSecondary)),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: state.recordingsPageSize,
                            isDense: true,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                            items: const [8, 15, 25, 50]
                                .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                ref.read(liveClassManagementProvider.notifier).setRecordingsPageSize(v);
                              }
                            },
                          ),
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

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double width = 125,
  }) {
    final uniqueItems = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty && !uniqueItems.contains(trimmed)) {
        uniqueItems.add(trimmed);
      }
    }
    final effectiveValue = uniqueItems.contains(value.trim())
        ? value.trim()
        : (uniqueItems.isNotEmpty ? uniqueItems.first : null);

    return Container(
      width: width,
      height: 32,
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: effectiveValue,
          width: width,
          isExpanded: false,
          compact: true,
          isDense: true,
          itemHeight: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          dropdownColor: cardBg,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            fontWeight: FontWeight.w500,
          ),
          items: uniqueItems
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPageButton(String text, bool isActive, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? LiveClassTheme.primary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isActive ? LiveClassTheme.primary(context) : cardBorder),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? Colors.white : textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewAndDetailsSection(RecordingItem? item) {
    if (item == null) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.video_library_rounded, size: 32, color: LiveClassTheme.primary(context)),
              ),
              const SizedBox(height: 14),
              Text(
                'No Recording Selected',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a recording from the table to preview playback and manage cloud storage.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final title = item.title;
    final classSection = item.classSection;
    final subject = item.subjectName;
    final duration = item.durationStr;
    final size = item.sizeStr;
    final recordedOn = item.dateTimeStr;
    final recType = item.type.isNotEmpty ? item.type : 'Live Class Session';
    final upperVis = item.visibility.toUpperCase();
    final visibilityLabel = upperVis == 'CLASS'
        ? 'Class Enrolled Only'
        : (upperVis == 'SCHOOL' || upperVis == 'SHARED'
            ? 'Entire School'
            : (upperVis == 'PRIVATE' ? 'Private (Teachers Only)' : item.visibility));
    final visibilityIcon = upperVis == 'PRIVATE'
        ? Icons.lock_outline_rounded
        : (upperVis == 'SCHOOL' || upperVis == 'SHARED'
            ? Icons.domain_rounded
            : Icons.group_rounded);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.ondemand_video_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                'Recording Preview',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Real Playable Video Player Box (Web HTML5 Video with Range Streaming, Seek, Speed, Volume, PiP & Fullscreen)
          RecordingPlayerWidget(
            item: item,
            resolvedStreamUrl: _resolvedStreamUrls[item.id],
            height: 190,
            onFirstPlay: () => ref.read(liveClassManagementProvider.notifier).trackRecordingView(item.id),
            onOpenFullscreenModal: () => _openFullscreenPlayer(item),
            onDownload: () => _downloadRecording(item),
          ),
          const SizedBox(height: 14),

          // Recording Details Section
          Text(
            'Recording Details',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.title_rounded, 'Title', title),
          _buildDetailRow(Icons.school_outlined, 'Class / Section', classSection),
          _buildDetailRow(Icons.menu_book_outlined, 'Subject', subject),
          _buildDetailRow(Icons.calendar_today_rounded, 'Recorded On', recordedOn),
          _buildDetailRow(Icons.schedule_rounded, 'Duration', duration),
          _buildDetailRow(Icons.storage_rounded, 'File Size', size),
          _buildDetailRow(Icons.videocam_outlined, 'Recording Type', recType),
          _buildDetailRow(visibilityIcon, 'Audience Visibility', visibilityLabel),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showShareDialog(item),
                  icon: const Icon(Icons.share, size: 14),
                  label: Text(
                    item.sharedCount > 0 ? 'Share (${item.sharedCount})' : 'Share',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadRecording(item),
                  icon: const Icon(Icons.file_download_outlined, size: 14),
                  label: const Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                    foregroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditDialog(item),
                  icon: Icon(Icons.edit_outlined, size: 14, color: textPrimary),
                  label: Text('Edit', style: TextStyle(fontSize: 12, color: textPrimary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDeleteRecording(item),
                  icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                  label: const Text('Delete', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: textSecondary),
          const SizedBox(width: 6),
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChartCard(List<AnalyticsDataPoint> points) {
    final displayPoints = points.isNotEmpty
        ? points
        : List.generate(
            6,
            (i) => AnalyticsDataPoint(date: 'Day ${i + 1}', views: 0, downloads: 0),
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_graph_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Recording Analytics (Last 30 Days)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Views', style: TextStyle(fontSize: 10, color: textSecondary)),
                  const SizedBox(width: 10),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF93C5FD), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Downloads', style: TextStyle(fontSize: 10, color: textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _AnalyticsLineChartPainter(displayPoints),
              size: const Size(double.infinity, 130),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: displayPoints
                .map((p) => Flexible(
                      child: Text(
                        p.date,
                        style: TextStyle(fontSize: 9, color: textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageUsageCard(RecordingsDashboardData? dashboard) {
    final storage = dashboard?.storageBreakdown;
    final usedGb = dashboard?.storageUsedGb ?? 0.0;
    final usedPct = dashboard?.storageUsedPercentage ?? 0;
    final totalTb = dashboard?.storageTotalTb ?? 1.0;
    final progressVal = (usedPct / 100.0).clamp(0.0, 1.0);
    final recGb = storage?.recordingsGb ?? 0.0;
    final recPct = storage?.recordingsPct ?? 0.0;
    final resGb = storage?.classResourcesGb ?? 0.0;
    final resPct = storage?.classResourcesPct ?? 0.0;
    final othGb = storage?.othersGb ?? 0.0;
    final othPct = storage?.othersPct ?? 0.0;
    final freeGb = storage?.freeSpaceGb ?? 1024.0;
    final freePct = storage?.freeSpacePct ?? 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Storage Usage',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: CircularProgressIndicator(
                        value: progressVal > 0 ? progressVal : 0.02,
                        strokeWidth: 10,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${usedGb.toStringAsFixed(2)} GB',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          'Used ($usedPct%)',
                          style: TextStyle(fontSize: 9, color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _buildStorageLegendRow('Recordings', '${recGb.toStringAsFixed(2)} GB (${recPct.toStringAsFixed(1)}%)', const Color(0xFF2563EB)),
                    const SizedBox(height: 4),
                    _buildStorageLegendRow('Class Resources', '${resGb.toStringAsFixed(2)} GB (${resPct.toStringAsFixed(1)}%)', const Color(0xFF10B981)),
                    const SizedBox(height: 4),
                    _buildStorageLegendRow('Others', '${othGb.toStringAsFixed(2)} GB (${othPct.toStringAsFixed(1)}%)', const Color(0xFFF59E0B)),
                    const SizedBox(height: 4),
                    _buildStorageLegendRow('Free Space', '${freeGb.toStringAsFixed(1)} GB (${freePct.toStringAsFixed(1)}%)', textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Storage: ${totalTb.toStringAsFixed(0)} TB', style: TextStyle(fontSize: 10, color: textSecondary)),
                  Text('$usedPct% Used', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressVal,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageLegendRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(fontSize: 10, color: textSecondary))),
        Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textPrimary)),
      ],
    );
  }

  Widget _buildRecordingSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Recording Settings',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const Spacer(),
              if (_isSavingSettings)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildToggleRow(
            icon: Icons.videocam_outlined,
            title: 'Auto Recording',
            value: _autoRecording,
            onChanged: (v) => _persistSettings(autoRecording: v),
          ),
          _buildToggleRow(
            icon: Icons.cloud_outlined,
            title: 'Cloud Storage',
            value: _cloudStorage,
            onChanged: (v) => _persistSettings(cloudStorage: v),
          ),
          _buildDropdownSettingRow(
            icon: Icons.timer_outlined,
            title: 'Default Retention Period',
            value: _retentionPeriod,
            options: ['90 Days', '180 Days', '365 Days', 'Unlimited'],
            onChanged: (v) {
              if (v != null) _persistSettings(retentionPeriod: v);
            },
          ),
          _buildDropdownSettingRow(
            icon: Icons.hd_outlined,
            title: 'Recording Quality',
            value: _recordingQuality,
            options: ['SD (480p)', 'HD (720p)', 'Full HD (1080p)'],
            onChanged: (v) {
              if (v != null) _persistSettings(recordingQuality: v);
            },
          ),
          _buildToggleRow(
            icon: Icons.file_download_outlined,
            title: 'Allow Student Download',
            value: _allowStudentDownload,
            onChanged: (v) => _persistSettings(allowStudentDownload: v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSettingRow({
    required IconData icon,
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final uniqueOptions = <String>[];
    for (final opt in options) {
      final trimmed = opt.trim();
      if (trimmed.isNotEmpty && !uniqueOptions.contains(trimmed)) {
        uniqueOptions.add(trimmed);
      }
    }
    final effectiveValue = uniqueOptions.contains(value.trim())
        ? value.trim()
        : (uniqueOptions.isNotEmpty ? uniqueOptions.first : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
          AppSearchableDropdown<String>.fromMenuItems(
            value: effectiveValue,
            width: 135,
            isDense: true,
            isExpanded: false,
            compact: true,
            underline: const SizedBox(),
            dropdownColor: cardBg,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
            items: uniqueOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsLineChartPainter extends CustomPainter {
  final List<AnalyticsDataPoint> dataPoints;
  _AnalyticsLineChartPainter(this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    final barPaint = Paint()
      ..color = const Color(0xFF93C5FD).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final count = dataPoints.length;
    if (count == 0) return;

    int maxVal = 1;
    for (final p in dataPoints) {
      if (p.views > maxVal) maxVal = p.views;
      if (p.downloads > maxVal) maxVal = p.downloads;
    }

    final points = <Offset>[];
    for (int i = 0; i < count; i++) {
      final fracX = count == 1 ? 0.5 : (0.05 + (i / (count - 1)) * 0.90);
      final fracY = 1.0 - (dataPoints[i].views / maxVal) * 0.78 - 0.08;
      points.add(Offset(size.width * fracX, size.height * fracY.clamp(0.08, 0.92)));
    }

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final dlFrac = (dataPoints[i].downloads / maxVal).clamp(0.0, 1.0);
      final barH = (size.height - 10) * dlFrac * 0.78;
      final barRect = Rect.fromLTWH(p.dx - 7, size.height - barH, 14, barH);
      canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(2)), barPaint);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _AnalyticsLineChartPainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints;
}
