import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';
import '../utils/live_class_theme.dart';
import '../widgets/create_instant_class_dialog.dart';
import '../widgets/live_class_stat_card.dart';

class RecordingsTab extends ConsumerStatefulWidget {
  const RecordingsTab({super.key});

  @override
  ConsumerState<RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends ConsumerState<RecordingsTab> {
  String _selectedSubnav = 'My Recordings';
  RecordingItem? _selectedRecording;
  final TextEditingController _searchCtrl = TextEditingController();

  // Settings state
  bool _autoRecording = true;
  bool _cloudStorage = true;
  String _retentionPeriod = '180 Days';
  String _recordingQuality = 'HD (720p)';
  bool _allowStudentDownload = true;

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
    super.dispose();
  }

  void _showCreateClassDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CreateInstantClassDialog(),
    );
  }

  void _showShareDialog(RecordingItem item) {
    final link = 'https://portal.edushamiit.com/recordings/${item.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Share Recording: ${item.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this recording link with students or staff:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: SelectableText(link, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(liveClassManagementProvider.notifier).shareRecording(item.id, 'ALL_STUDENTS');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recording shared successfully!')),
              );
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share Access'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveClassManagementProvider);
    final dashboard = state.recordingsDashboard;
    final recordings = state.recordings;

    final currentSelected = _selectedRecording ??
        (recordings.isNotEmpty ? recordings.first : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top KPI Row (7 Cards matching Image 2)
          _buildKpiRow(dashboard),
          const SizedBox(height: 16),

          // 2. Middle Main Workspace (Left subnav + Center table + Right Preview & Details)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 950;
              final isMedium = constraints.maxWidth < 1250;

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHorizontalSubnav(),
                    const SizedBox(height: 12),
                    _buildRecordingsTableSection(recordings, state, currentSelected),
                    const SizedBox(height: 12),
                    _buildPreviewAndDetailsSection(currentSelected),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: isMedium ? 180 : 200,
                    child: _buildLeftSubnav(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 7,
                    child: _buildRecordingsTableSection(recordings, state, currentSelected),
                  ),
                  const SizedBox(width: 14),
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
                    _buildAnalyticsChartCard(),
                    const SizedBox(height: 12),
                    _buildStorageUsageCard(dashboard?.storageBreakdown),
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
                    child: _buildAnalyticsChartCard(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildStorageUsageCard(dashboard?.storageBreakdown),
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

  Widget _buildHorizontalSubnav() {
    final items = [
      (Icons.video_library_rounded, 'My Recordings'),
      (Icons.grid_view_rounded, 'All Recordings'),
      (Icons.school_outlined, 'By Class / Section'),
      (Icons.menu_book_outlined, 'By Subject'),
      (Icons.share_outlined, 'Shared Recordings'),
      (Icons.assignment_turned_in_outlined, 'Recording Requests'),
      (Icons.cloud_queue_rounded, 'Storage & Retention'),
      (Icons.cloud_upload_outlined, 'Upload Recording'),
      (Icons.rule_folder_outlined, 'Auto Recording Rules'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showCreateClassDialog,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('New Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 8),
            ...items.map((item) {
              final isSelected = _selectedSubnav == item.$2;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  avatar: Icon(
                    item.$1,
                    size: 14,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                  label: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1D4ED8),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                  onSelected: (val) {
                    setState(() => _selectedSubnav = item.$2);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(RecordingsDashboardData? data) {
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
                    value: '${data?.totalRecordings ?? 486}',
                    icon: Icons.video_library_rounded,
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 175,
                  child: LiveClassStatCard(
                    title: 'This Week',
                    value: '${data?.thisWeek ?? 28}',
                    icon: Icons.play_circle_fill_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 190,
                  child: LiveClassStatCard(
                    title: 'Total Duration',
                    value: data?.totalDurationDisplay ?? '362 h 14 min',
                    icon: Icons.schedule_rounded,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 205,
                  child: LiveClassStatCard(
                    title: 'Storage Used',
                    value: '${data?.storageUsedGb ?? 728.4} GB',
                    subtitle: '(${data?.storageUsedPercentage ?? 71}%)',
                    icon: Icons.cloud_done_rounded,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 185,
                  child: LiveClassStatCard(
                    title: 'Total Downloads',
                    value: '${data?.totalDownloads ?? 1842}',
                    icon: Icons.file_download_outlined,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 195,
                  child: LiveClassStatCard(
                    title: 'Avg. Views / Recording',
                    value: '${data?.avgViews ?? 38}',
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 175,
                  child: LiveClassStatCard(
                    title: 'Retention Rate',
                    value: '${data?.retentionRatePct ?? 96}%',
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
                value: '${data?.totalRecordings ?? 486}',
                icon: Icons.video_library_rounded,
                iconColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'This Week',
                value: '${data?.thisWeek ?? 28}',
                icon: Icons.play_circle_fill_rounded,
                iconColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Total Duration',
                value: data?.totalDurationDisplay ?? '362 h 14 min',
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Storage Used',
                value: '${data?.storageUsedGb ?? 728.4} GB',
                subtitle: '(${data?.storageUsedPercentage ?? 71}%)',
                icon: Icons.cloud_done_rounded,
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Total Downloads',
                value: '${data?.totalDownloads ?? 1842}',
                icon: Icons.file_download_outlined,
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Avg. Views / Recording',
                value: '${data?.avgViews ?? 38}',
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Retention Rate',
                value: '${data?.retentionRatePct ?? 96}%',
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeftSubnav() {
    return Container(
      padding: const EdgeInsets.all(12),
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
          ElevatedButton.icon(
            onPressed: _showCreateClassDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Start New Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cardDivider),
          const SizedBox(height: 10),
          _buildSubnavItem(Icons.video_library_rounded, 'My Recordings'),
          _buildSubnavItem(Icons.grid_view_rounded, 'All Recordings'),
          _buildSubnavItem(Icons.school_outlined, 'By Class / Section'),
          _buildSubnavItem(Icons.menu_book_outlined, 'By Subject'),
          _buildSubnavItem(Icons.share_outlined, 'Shared Recordings'),
          _buildSubnavItem(Icons.assignment_turned_in_outlined, 'Recording Requests'),
          _buildSubnavItem(Icons.cloud_queue_rounded, 'Storage & Retention'),
          _buildSubnavItem(Icons.cloud_upload_outlined, 'Upload Recording'),
          _buildSubnavItem(Icons.rule_folder_outlined, 'Auto Recording Rules'),
        ],
      ),
    );
  }

  Widget _buildSubnavItem(IconData icon, String label) {
    final isSelected = _selectedSubnav == label;

    return InkWell(
      onTap: () {
        setState(() => _selectedSubnav = label);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: const Color(0xFF3B82F6), width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF3B82F6) : textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? (isDark ? Colors.white : const Color(0xFF1D4ED8)) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                ),
                overflow: TextOverflow.ellipsis,
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
          // Header with View Analytics
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.video_library_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      'My Recordings',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Text('View Analytics', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterDropdown(
                  value: classes.where((c) => c.id == state.recordingClassFilter).firstOrNull?.name ?? 'All Classes',
                  items: ['All Classes', ...classes.map((e) => e.name)],
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
                  items: ['All Teachers', ...(meta?.teachers.map((t) => t.name) ?? ['R. Kumar', 'P. Sharma', 'A. Gupta'])],
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
                  value: 'All Dates',
                  items: const ['All Dates', 'Today', 'This Week', 'This Month'],
                  onChanged: (_) {},
                ),
                _buildFilterDropdown(
                  value: 'Recording Type',
                  items: const ['Recording Type', 'Auto (Live Class)', 'Uploaded'],
                  onChanged: (_) {},
                ),
                SizedBox(
                  width: 170,
                  height: 32,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
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
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Scrollable Table Area
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 960,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: headerRowBg,
                    child: Row(
                      children: [
                        SizedBox(width: 24, child: Icon(Icons.check_box_outline_blank, size: 16, color: textSecondary)),
                        const SizedBox(width: 8),
                        SizedBox(width: 230, child: Text('Recording Title', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 90, child: Text('Class / Section', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
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
                    itemCount: recordings.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: cardDivider),
                    itemBuilder: (context, index) {
                      final rec = recordings[index];
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
                              SizedBox(width: 24, child: Icon(Icons.check_box_outline_blank, size: 16, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                              const SizedBox(width: 8),
                              // Title with Play Icon
                              SizedBox(
                                width: 230,
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
                              SizedBox(width: 90, child: Text(rec.classSection, style: TextStyle(fontSize: 11, color: textSecondary), overflow: TextOverflow.ellipsis)),
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
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Downloading ${rec.title}...')),
                                        );
                                      },
                                      child: const Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF2563EB)),
                                    ),
                                    const SizedBox(width: 6),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, size: 16, color: textSecondary),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onSelected: (val) {
                                        if (val == 'share') _showShareDialog(rec);
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'share', child: Text('Share Recording', style: TextStyle(fontSize: 12))),
                                        const PopupMenuItem(value: 'details', child: Text('View Details', style: TextStyle(fontSize: 12))),
                                        const PopupMenuItem(value: 'delete', child: Text('Delete Recording', style: TextStyle(fontSize: 12, color: Colors.red))),
                                      ],
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

          // Pagination Footer
          Container(
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
                    Text('8', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                    Icon(Icons.arrow_drop_down, size: 16, color: textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
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
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          dropdownColor: cardBg,
          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontWeight: FontWeight.w500),
          items: uniqueItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
    final recType = item.visibility;

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

          // Video Player Box
          Container(
            height: 165,
            decoration: BoxDecoration(
              color: const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                // Blackboard screenshot placeholder
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ax² + bx + c = 0',
                        style: TextStyle(color: Color(0xFF93C5FD), fontSize: 16, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                // Play overlay button
                Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  ),
                ),
                // Bottom Player Controls Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pause_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        const Text('12:36 / 45:00', style: TextStyle(fontSize: 10, color: Colors.white)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: LinearProgressIndicator(
                            value: 0.28,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                            minHeight: 3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.volume_up_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white30),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('1.0x', style: TextStyle(fontSize: 9, color: Colors.white)),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showShareDialog(item),
                  icon: const Icon(Icons.share, size: 14),
                  label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading recording...')),
                    );
                  },
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
                  onPressed: () {},
                  icon: Icon(Icons.edit_outlined, size: 14, color: textSecondary),
                  label: Text('Edit', style: TextStyle(fontSize: 12, color: textSecondary)),
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
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: cardBg,
                        title: Text('Delete Recording?', style: TextStyle(color: textPrimary)),
                        content: Text('This will permanently delete this cloud recording.', style: TextStyle(color: textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Recording deleted.')),
                              );
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
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

  Widget _buildAnalyticsChartCard() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Recording Analytics (Last 30 Days)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ],
              ),
              Row(
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
          // Chart Graphic
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _AnalyticsLineChartPainter(),
              size: const Size(double.infinity, 130),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('22 Dec', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('25 Dec', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('28 Dec', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('31 Dec', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('03 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('06 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('09 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('12 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('15 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('18 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
              Text('21 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageUsageCard(StorageBreakdown? storage) {
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
              // Circular Donut
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
                        value: 0.71,
                        strokeWidth: 10,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '728.4 GB',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          'Used (71%)',
                          style: TextStyle(fontSize: 9, color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Breakdown List
              Expanded(
                child: Column(
                  children: [
                    _buildStorageLegendRow('Recordings', '612.3 GB (59.8%)', const Color(0xFF2563EB)),
                    const SizedBox(height: 4),
                    _buildStorageLegendRow('Class Resources', '94.6 GB (9.2%)', const Color(0xFF10B981)),
                    const SizedBox(height: 4),
                    _buildStorageLegendRow('Others', '21.5 GB (2.0%)', const Color(0xFFF59E0B)),
                    const SizedBox(height: 4),
                    _buildStorageLegendRow('Free Space', '295.6 GB (29.0%)', textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Storage: 1 TB', style: TextStyle(fontSize: 10, color: textSecondary)),
                  Text('71% Used', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.71,
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
            ],
          ),
          const SizedBox(height: 10),
          _buildToggleRow(
            icon: Icons.videocam_outlined,
            title: 'Auto Recording',
            value: _autoRecording,
            onChanged: (v) => setState(() => _autoRecording = v),
          ),
          _buildToggleRow(
            icon: Icons.cloud_outlined,
            title: 'Cloud Storage',
            value: _cloudStorage,
            onChanged: (v) => setState(() => _cloudStorage = v),
          ),
          _buildDropdownSettingRow(
            icon: Icons.timer_outlined,
            title: 'Default Retention Period',
            value: _retentionPeriod,
            options: ['90 Days', '180 Days', '365 Days', 'Unlimited'],
            onChanged: (v) => setState(() => _retentionPeriod = v!),
          ),
          _buildDropdownSettingRow(
            icon: Icons.hd_outlined,
            title: 'Recording Quality',
            value: _recordingQuality,
            options: ['SD (480p)', 'HD (720p)', 'Full HD (1080p)'],
            onChanged: (v) => setState(() => _recordingQuality = v!),
          ),
          _buildToggleRow(
            icon: Icons.file_download_outlined,
            title: 'Allow Student Download',
            value: _allowStudentDownload,
            onChanged: (v) => setState(() => _allowStudentDownload = v),
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
          DropdownButton<String>(
            value: effectiveValue,
            isDense: true,
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
      ..color = const Color(0xFFBFDBFE).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final points = [
      Offset(size.width * 0.05, size.height * 0.8),
      Offset(size.width * 0.15, size.height * 0.72),
      Offset(size.width * 0.25, size.height * 0.65),
      Offset(size.width * 0.35, size.height * 0.68),
      Offset(size.width * 0.45, size.height * 0.52),
      Offset(size.width * 0.55, size.height * 0.55),
      Offset(size.width * 0.65, size.height * 0.42),
      Offset(size.width * 0.75, size.height * 0.45),
      Offset(size.width * 0.85, size.height * 0.35),
      Offset(size.width * 0.95, size.height * 0.2),
    ];

    // Draw bars
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final barRect = Rect.fromLTWH(p.dx - 8, p.dy + 8, 16, size.height - (p.dy + 8));
      canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(2)), barPaint);
    }

    // Draw line
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw dots
    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
