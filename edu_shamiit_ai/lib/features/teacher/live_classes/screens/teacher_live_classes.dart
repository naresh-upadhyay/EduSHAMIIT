import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class TeacherLiveClasses extends ConsumerStatefulWidget {
  const TeacherLiveClasses({super.key});

  @override
  ConsumerState<TeacherLiveClasses> createState() => _TeacherLiveClassesState();
}

class _TeacherLiveClassesState extends ConsumerState<TeacherLiveClasses> {
  final TeacherApiService _apiService = TeacherApiService();

  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'Scheduled', 'Ongoing', 'Completed'];
  List<TeacherLiveClass> _liveClasses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLiveClasses();
  }

  Future<void> _loadLiveClasses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final liveClasses = await _apiService.getLiveClasses(status: null);
      setState(() {
        _liveClasses = liveClasses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Live Classes Studio',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.video_call, color: Colors.white),
                  onPressed: () => _showScheduleDialog(),
                ),
              ],
            ),
          ),

          // Loading state / Error / Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFEF4444)),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $_error',
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadLiveClasses,
                              child: Text('Retry'.tr(ref)),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        child: AzureGrid<TeacherLiveClass>(
                          title: 'All Live Classes',
                          items: _liveClasses,
                          onRefresh: _loadLiveClasses,
                          extraCommandActions: [
                            IconButton(
                              icon: const Icon(Icons.video_call,
                                  color: Color(0xFFEF4444)),
                              tooltip: 'Schedule Class',
                              onPressed: _showScheduleDialog,
                            ),
                          ],
                          searchMatcher: (item) =>
                              '${item.title} ${item.subject} ${item.class_} ${item.platform} ${item.status}',
                          filters: [
                            AzureGridFilter<TeacherLiveClass>(
                              label: 'Status',
                              options: const [
                                'Scheduled',
                                'Ongoing/Live',
                                'Completed',
                                'Recorded'
                              ],
                              filterFn: (item, option) {
                                final status = item.status.toLowerCase();
                                if (option == 'Scheduled') {
                                  return status == 'scheduled';
                                }
                                if (option == 'Ongoing/Live') {
                                  return status == 'ongoing' ||
                                      status == 'live';
                                }
                                if (option == 'Completed') {
                                  return status == 'completed';
                                }
                                if (option == 'Recorded') {
                                  return status == 'recorded';
                                }
                                return true;
                              },
                            ),
                            AzureGridFilter<TeacherLiveClass>(
                              label: 'Class',
                              options: _liveClasses
                                  .map((e) => e.class_)
                                  .where((c) => c.isNotEmpty)
                                  .toSet()
                                  .toList(),
                              filterFn: (item, option) =>
                                  item.class_ == option,
                            ),
                            AzureGridFilter<TeacherLiveClass>(
                              label: 'Subject',
                              options: _liveClasses
                                  .map((e) => e.subject)
                                  .where((s) => s.isNotEmpty)
                                  .toSet()
                                  .toList(),
                              filterFn: (item, option) =>
                                  item.subject == option,
                            ),
                          ],
                          columns: [
                            AzureGridColumn<TeacherLiveClass>(
                              label: 'Title & Subject',
                              width: 250,
                              compare: (a, b) =>
                                  a.title.compareTo(b.title),
                              cellBuilder: (item) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subject,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            AzureGridColumn<TeacherLiveClass>(
                              label: 'Class',
                              width: 100,
                              compare: (a, b) =>
                                  a.class_.compareTo(b.class_),
                              cellBuilder: (item) => Text(item.class_),
                            ),
                            AzureGridColumn<TeacherLiveClass>(
                              label: 'Scheduled Time',
                              width: 160,
                              compare: (a, b) =>
                                  a.scheduledAt.compareTo(b.scheduledAt),
                              cellBuilder: (item) => Text(
                                item.scheduledAt
                                    .toString()
                                    .split('.')[0]
                                    .substring(0, 16),
                              ),
                            ),
                            AzureGridColumn<TeacherLiveClass>(
                              label: 'Duration',
                              width: 90,
                              compare: (a, b) => (a.durationMinutes ?? 0)
                                  .compareTo(b.durationMinutes ?? 0),
                              cellBuilder: (item) => Text(
                                  '${item.durationMinutes ?? 60} mins'),
                            ),
                            AzureGridColumn<TeacherLiveClass>(
                              label: 'Platform',
                              width: 110,
                              compare: (a, b) =>
                                  a.platform.compareTo(b.platform),
                              cellBuilder: (item) =>
                                  _buildPlatformBadge(item.platform),
                            ),
                            AzureGridColumn<TeacherLiveClass>(
                              label: 'Status',
                              width: 120,
                              compare: (a, b) =>
                                  a.status.compareTo(b.status),
                              cellBuilder: (item) {
                                final statusLower = item.status.toLowerCase();
                                final isLive = statusLower == 'ongoing' ||
                                    statusLower == 'live';
                                final isScheduled = statusLower == 'scheduled';

                                if (isLive) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: const Color(0xFFEF4444)
                                              .withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'LIVE NOW',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (isScheduled) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SCHEDULED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  );
                                } else {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'COMPLETED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            AzureGridColumn<TeacherLiveClass>(
                              label: 'Actions',
                              width: 180,
                              cellBuilder: (item) {
                                final statusLower = item.status.toLowerCase();
                                final isLive = statusLower == 'ongoing' ||
                                    statusLower == 'live';
                                final isScheduled = statusLower == 'scheduled';

                                Widget actionBtn;
                                if (isLive) {
                                  actionBtn = ElevatedButton.icon(
                                    onPressed: () => _joinBroadcasting(item),
                                    icon: const Icon(Icons.video_call,
                                        color: Colors.white, size: 12),
                                    label: const Text(
                                      'Studio',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: const Size(60, 28),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                  );
                                } else if (isScheduled) {
                                  actionBtn = ElevatedButton.icon(
                                    onPressed: () => _startBroadcasting(item),
                                    icon: const Icon(Icons.play_arrow_rounded,
                                        color: Colors.white, size: 12),
                                    label: const Text(
                                      'Start',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: const Size(60, 28),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                  );
                                } else {
                                  actionBtn = ElevatedButton.icon(
                                    onPressed: () => _watchRecording(item),
                                    icon: const Icon(Icons.play_circle_outline,
                                        color: Colors.white, size: 12),
                                    label: const Text(
                                      'Playback',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF475569),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: const Size(60, 28),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                  );
                                }

                                return Row(
                                  children: [
                                    actionBtn,
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          size: 16, color: Color(0xFF64748B)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onSelected: (value) {
                                        if (value == 'watch') {
                                          _watchRecording(item);
                                        } else if (value == 'edit') {
                                          _showEditDialog(item);
                                        } else if (value == 'delete') {
                                          _confirmDelete(item);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (statusLower == 'recorded' ||
                                            statusLower == 'completed')
                                          const PopupMenuItem(
                                            value: 'watch',
                                            child: Row(
                                              children: [
                                                Icon(
                                                    Icons.play_circle_outline,
                                                    size: 14),
                                                SizedBox(width: 6),
                                                Text('Watch Recording',
                                                    style: TextStyle(
                                                        fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 14),
                                              SizedBox(width: 6),
                                              Text('Edit Class',
                                                  style:
                                                      TextStyle(fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  size: 14, color: Colors.red),
                                              SizedBox(width: 6),
                                              Text('Delete Class',
                                                  style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                          mobileCardBuilder: (context, item) =>
                              _buildLiveClassCard(item),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBadge(String platform) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF334155);
    IconData icon = Icons.video_call;

    final lower = platform.toLowerCase();
    if (lower == 'zoom') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      icon = Icons.videocam;
    } else if (lower.contains('meet') || lower.contains('google')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      icon = Icons.groups;
    } else if (lower == 'youtube') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      icon = Icons.play_circle_fill;
    } else if (lower == 'in-app' || lower == 'edushamiit') {
      bg = const Color(0xFFEEF2FF);
      fg = const Color(0xFF4338CA);
      icon = Icons.bolt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              platform,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold, color: fg),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveClassCard(TeacherLiveClass liveClass) {
    final statusLower = liveClass.status.toLowerCase();
    final isLive = statusLower == 'ongoing' || statusLower == 'live';
    final isScheduled = statusLower == 'scheduled';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive ? const Color(0xFFFCA5A5) : const Color(0xFFF1F5F9),
          width: isLive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLive
                ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: isLive
                ? const LinearGradient(
                    colors: [Color(0xFFFFF5F5), Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject Circular Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isLive
                            ? [const Color(0xFFEF4444), const Color(0xFFF87171)]
                            : [
                                const Color(0xFF64748B),
                                const Color(0xFF94A3B8)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (isLive
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF64748B))
                              .withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        liveClass.subject.isNotEmpty
                            ? liveClass.subject[0].toUpperCase()
                            : '📚',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title and Subtitles
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          liveClass.title,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Class ${liveClass.class_}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildPlatformBadge(liveClass.platform),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status Badge
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE NOW',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEF4444),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isScheduled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'SCHEDULED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D4ED8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      if (!isLive) ...[
                        const SizedBox(height: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 20, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'watch') {
                              _watchRecording(liveClass);
                            } else if (value == 'edit') {
                              _showEditDialog(liveClass);
                            } else if (value == 'delete') {
                              _confirmDelete(liveClass);
                            }
                          },
                          itemBuilder: (context) => [
                            if (statusLower == 'recorded' ||
                                statusLower == 'completed')
                              const PopupMenuItem(
                                value: 'watch',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_circle_outline, size: 16),
                                    SizedBox(width: 8),
                                    Text('Watch Recording'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Class'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Class',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 16),
              // Time and Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        liveClass.scheduledAt
                            .toString()
                            .split('.')[0]
                            .substring(0, 16),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.book_outlined,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        liveClass.subject,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (isLive)
                    ElevatedButton.icon(
                      onPressed: () => _joinBroadcasting(liveClass),
                      icon: const Icon(Icons.video_call,
                          color: Colors.white, size: 16),
                      label: const Text(
                        'Open Studio',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shadowColor:
                            const Color(0xFF10B981).withValues(alpha: 0.3),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else if (isScheduled)
                    ElevatedButton.icon(
                      onPressed: () => _startBroadcasting(liveClass),
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 16),
                      label: const Text(
                        'Start Class',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shadowColor:
                            const Color(0xFFEF4444).withValues(alpha: 0.3),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _watchRecording(liveClass),
                      icon: const Icon(Icons.play_circle_outline,
                          color: Colors.white, size: 16),
                      label: const Text(
                        'Watch Playback',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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

  Future<void> _startBroadcasting(TeacherLiveClass liveClass) async {
    try {
      await _apiService.patchLiveClass(liveClass.id, {
        "status": "live",
      });
      _loadLiveClasses();
      if (mounted) {
        final platformLower = liveClass.platform.toLowerCase();
        if (platformLower == 'in-app' || platformLower == 'edushamiit') {
          final auth = ref.read(authProvider);
          context.push(
            '/live-room',
            extra: {
              'liveClassId': liveClass.id,
              'currentUserId': auth.userData?['id'] ?? '',
              'currentUserName': auth.userData?['full_name'] ?? 'Teacher',
              'currentUserRole': 'teacher',
              'title': liveClass.title,
            },
          ).then((_) => _loadLiveClasses());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  _TeacherLiveBroadcastingScreen(liveClass: liveClass),
            ),
          ).then((_) => _loadLiveClasses());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error starting class: $e')),
        );
      }
    }
  }

  void _joinBroadcasting(TeacherLiveClass liveClass) {
    final platformLower = liveClass.platform.toLowerCase();
    if (platformLower == 'in-app' || platformLower == 'edushamiit') {
      final auth = ref.read(authProvider);
      context.push(
        '/live-room',
        extra: {
          'liveClassId': liveClass.id,
          'currentUserId': auth.userData?['id'] ?? '',
          'currentUserName': auth.userData?['full_name'] ?? 'Teacher',
          'currentUserRole': 'teacher',
          'title': liveClass.title,
        },
      ).then((_) => _loadLiveClasses());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              _TeacherLiveBroadcastingScreen(liveClass: liveClass),
        ),
      ).then((_) => _loadLiveClasses());
    }
  }

  void _showScheduleDialog() {
    final titleController = TextEditingController();
    final linkController = TextEditingController(text: 'In-App');
    final durationController = TextEditingController(text: '60');

    // Will be loaded dynamically from teacher's classes/subjects
    List<String> availableClasses = [];
    List<String> availableSubjects = [];
    String? selectedClass;
    String? selectedSubject;
    String selectedPlatform = 'In-App';
    DateTime selectedDateTime = DateTime.now().add(const Duration(hours: 1));
    bool isUploadRecording = false;
    bool isSubmitting = false;
    bool isLoadingMeta = true; // loading classes+subjects

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Kick off loading once when dialog first opens
            if (isLoadingMeta && availableClasses.isEmpty) {
              Future.microtask(() async {
                try {
                  final classes = await _apiService.getMyClasses();
                  final subjects = await _apiService.getSubjects();
                  final classNames = classes
                      .map((c) => c.name)
                      .where((n) => n.isNotEmpty)
                      .toSet()
                      .toList();
                  final subjectNames = subjects
                      .map((s) => s.name)
                      .where((n) => n.isNotEmpty)
                      .toSet()
                      .toList();
                  if (context.mounted) {
                    setDialogState(() {
                      availableClasses = classNames.isNotEmpty
                          ? classNames
                          : ['No Classes Found'];
                      availableSubjects = subjectNames.isNotEmpty
                          ? subjectNames
                          : ['No Subjects Found'];
                      selectedClass = availableClasses.first;
                      selectedSubject = availableSubjects.first;
                      isLoadingMeta = false;
                    });
                  }
                } catch (_) {
                  if (context.mounted) {
                    setDialogState(() {
                      availableClasses = ['N/A'];
                      availableSubjects = ['N/A'];
                      selectedClass = 'N/A';
                      selectedSubject = 'N/A';
                      isLoadingMeta = false;
                    });
                  }
                }
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.video_call,
                      color: Color(0xFFEF4444), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    isUploadRecording
                        ? 'Upload Recording'
                        : 'Schedule Live Class',
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              content: isLoadingMeta
                  ? const SizedBox(
                      height: 100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFEF4444)),
                            SizedBox(height: 12),
                            Text('Loading your classes...',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tab Switcher
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(() {
                                    isUploadRecording = false;
                                    selectedPlatform = 'In-App';
                                    linkController.text = 'In-App';
                                  }),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !isUploadRecording
                                          ? const Color(0xFFEF4444)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: !isUploadRecording
                                              ? Colors.transparent
                                              : Colors.white10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Live Class',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: !isUploadRecording
                                              ? Colors.white
                                              : Colors.white60,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(() {
                                    isUploadRecording = true;
                                    linkController.text =
                                        'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&modestbranding=1&rel=0';
                                  }),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isUploadRecording
                                          ? const Color(0xFFEF4444)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: isUploadRecording
                                              ? Colors.transparent
                                              : Colors.white10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Recording',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isUploadRecording
                                              ? Colors.white
                                              : Colors.white60,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Title Field
                          const Text('Class Title',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: titleController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: isUploadRecording
                                  ? 'e.g. Physics — Wave Optics'
                                  : 'e.g. Physics — Optics Chapter 9',
                              hintStyle: const TextStyle(color: Colors.white30),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Target Class & Subject Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Target Class',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: (selectedClass != null &&
                                              availableClasses
                                                  .contains(selectedClass))
                                          ? selectedClass
                                          : (availableClasses.isNotEmpty
                                              ? availableClasses.first
                                              : null),
                                      dropdownColor: const Color(0xFF1E293B),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                      items: availableClasses
                                          .map((c) => DropdownMenuItem(
                                              value: c, child: Text(c)))
                                          .toList(),
                                      onChanged: (val) => setDialogState(
                                          () => selectedClass = val),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Subject',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: (selectedSubject != null &&
                                              availableSubjects
                                                  .contains(selectedSubject))
                                          ? selectedSubject
                                          : (availableSubjects.isNotEmpty
                                              ? availableSubjects.first
                                              : null),
                                      dropdownColor: const Color(0xFF1E293B),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                      items: availableSubjects
                                          .map((s) => DropdownMenuItem(
                                              value: s, child: Text(s)))
                                          .toList(),
                                      onChanged: (val) => setDialogState(
                                          () => selectedSubject = val),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Platform Selector (only if not recording)
                          if (!isUploadRecording) ...[
                            const Text('Platform',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedPlatform,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              items: [
                                'In-App',
                                'Zoom',
                                'Google Meet',
                                'YouTube'
                              ]
                                  .map((p) => DropdownMenuItem(
                                      value: p, child: Text(p)))
                                  .toList(),
                              onChanged: (val) => setDialogState(() {
                                selectedPlatform = val ?? 'In-App';
                                if (selectedPlatform == 'In-App') {
                                  linkController.text = 'In-App';
                                } else if (selectedPlatform == 'Zoom') {
                                  linkController.text =
                                      'https://zoom.us/j/1234567890';
                                } else if (selectedPlatform == 'Google Meet') {
                                  linkController.text =
                                      'https://meet.google.com/abc-defg-hij';
                                } else if (selectedPlatform == 'YouTube') {
                                  linkController.text =
                                      'https://www.youtube.com/embed/dQw4w9WgXcQ';
                                }
                              }),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Date & Time Picker (if scheduling upcoming)
                          if (!isUploadRecording) ...[
                            const Text('Scheduled Time',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDateTime,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 30)),
                                );
                                if (date != null && context.mounted) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                        selectedDateTime),
                                  );
                                  if (time != null) {
                                    setDialogState(() {
                                      selectedDateTime = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        color: Colors.white54, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedDateTime.toString().split('.')[0],
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Duration and Stream/Recording Link
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Duration (min)',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: durationController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isUploadRecording ||
                                  selectedPlatform != 'In-App') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isUploadRecording
                                            ? 'Recording Embed URL'
                                            : 'Meeting / Stream URL',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: linkController,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFF0F172A),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final link = linkController.text.trim();
                          final duration =
                              int.tryParse(durationController.text.trim()) ??
                                  60;

                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('⚠️ Title is required')),
                            );
                            return;
                          }
                          if ((isUploadRecording ||
                                  selectedPlatform != 'In-App') &&
                              link.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('⚠️ URL link is required')),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          setDialogState(() => isSubmitting = true);

                          try {
                            await _apiService.createLiveClass(
                              title: title,
                              classId: selectedClass ?? '',
                              subject: selectedSubject ?? '',
                              scheduledAt: isUploadRecording
                                  ? DateTime.now()
                                  : selectedDateTime,
                              durationMinutes: duration,
                              status:
                                  isUploadRecording ? 'recorded' : 'scheduled',
                              streamUrl: isUploadRecording
                                  ? null
                                  : (selectedPlatform == 'In-App'
                                      ? 'In-App'
                                      : link),
                              recordingUrl: isUploadRecording ? link : null,
                              platform: isUploadRecording
                                  ? 'Recorded'
                                  : selectedPlatform,
                              meetingLink: isUploadRecording
                                  ? null
                                  : (selectedPlatform == 'In-App'
                                      ? 'In-App'
                                      : link),
                            );

                            navigator.pop();
                            _loadLiveClasses();

                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      isUploadRecording
                                          ? 'Recorded class uploaded successfully!'
                                          : 'Live class scheduled successfully!',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('❌ Error: $e')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isUploadRecording ? 'Upload' : 'Schedule',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _watchRecording(TeacherLiveClass liveClass) {
    context.go('/teacher/live-classes/play/${liveClass.id}');
  }

  void _confirmDelete(TeacherLiveClass liveClass) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444), size: 28),
              SizedBox(width: 8),
              Text(
                'Delete Class',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${liveClass.title}"? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteLiveClass(liveClass.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteLiveClass(String id) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _apiService.deleteLiveClass(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('✅ Live class deleted successfully.'),
          ),
        );
      }
      _loadLiveClasses();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error deleting class: $e')),
        );
      }
    }
  }

  void _showEditDialog(TeacherLiveClass liveClass) {
    final titleController = TextEditingController(text: liveClass.title);
    final linkController = TextEditingController(
        text: liveClass.meetingLink ?? liveClass.recordingUrl ?? '');
    final durationController = TextEditingController(
        text: (liveClass.durationMinutes ?? 60).toString());

    List<String> availableClasses = [];
    List<String> availableSubjects = [];
    String? selectedClass;
    String? selectedSubject;
    String selectedPlatform = liveClass.platform;
    String selectedStatus = liveClass.status;
    DateTime selectedDateTime = liveClass.scheduledAt;
    bool isSubmitting = false;
    bool isLoadingMeta = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isLoadingMeta && availableClasses.isEmpty) {
              Future.microtask(() async {
                try {
                  final classes = await _apiService.getMyClasses();
                  final subjects = await _apiService.getSubjects();
                  final classNames = classes
                      .map((c) => c.name)
                      .where((n) => n.isNotEmpty)
                      .toSet()
                      .toList();
                  final subjectNames = subjects
                      .map((s) => s.name)
                      .where((n) => n.isNotEmpty)
                      .toSet()
                      .toList();
                  if (context.mounted) {
                    setDialogState(() {
                      availableClasses = classNames.isNotEmpty
                          ? classNames
                          : ['No Classes Found'];
                      availableSubjects = subjectNames.isNotEmpty
                          ? subjectNames
                          : ['No Subjects Found'];

                      selectedClass = availableClasses.firstWhere(
                        (c) =>
                            c.toLowerCase() == liveClass.class_.toLowerCase(),
                        orElse: () => availableClasses.first,
                      );
                      selectedSubject = availableSubjects.firstWhere(
                        (s) =>
                            s.toLowerCase() == liveClass.subject.toLowerCase(),
                        orElse: () => availableSubjects.first,
                      );
                      isLoadingMeta = false;
                    });
                  }
                } catch (_) {
                  if (context.mounted) {
                    setDialogState(() {
                      availableClasses = [liveClass.class_];
                      availableSubjects = [liveClass.subject];
                      selectedClass = liveClass.class_;
                      selectedSubject = liveClass.subject;
                      isLoadingMeta = false;
                    });
                  }
                }
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Color(0xFFEF4444), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Edit Live Class',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              content: isLoadingMeta
                  ? const SizedBox(
                      height: 100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFEF4444)),
                            SizedBox(height: 12),
                            Text('Loading class metadata...',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Class Title',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: titleController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Target Class',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedClass,
                                      dropdownColor: const Color(0xFF0F172A),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                      items: availableClasses
                                          .map((c) => DropdownMenuItem(
                                              value: c, child: Text(c)))
                                          .toList(),
                                      onChanged: (val) => setDialogState(
                                          () => selectedClass = val),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Subject',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedSubject,
                                      dropdownColor: const Color(0xFF0F172A),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                      items: availableSubjects
                                          .map((s) => DropdownMenuItem(
                                              value: s, child: Text(s)))
                                          .toList(),
                                      onChanged: (val) => setDialogState(
                                          () => selectedSubject = val),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Platform',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: [
                                        'In-App',
                                        'Zoom',
                                        'Google Meet',
                                        'YouTube',
                                        'Recorded'
                                      ].contains(selectedPlatform)
                                          ? selectedPlatform
                                          : 'In-App',
                                      dropdownColor: const Color(0xFF0F172A),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                      items: [
                                        'In-App',
                                        'Zoom',
                                        'Google Meet',
                                        'YouTube',
                                        'Recorded'
                                      ]
                                          .map((p) => DropdownMenuItem(
                                              value: p, child: Text(p)))
                                          .toList(),
                                      onChanged: (val) => setDialogState(() =>
                                          selectedPlatform = val ?? 'In-App'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Status',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: [
                                        'scheduled',
                                        'ongoing',
                                        'live',
                                        'completed',
                                        'recorded',
                                        'cancelled'
                                      ].contains(selectedStatus.toLowerCase())
                                          ? selectedStatus.toLowerCase()
                                          : 'scheduled',
                                      dropdownColor: const Color(0xFF0F172A),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'scheduled',
                                            child: Text('Scheduled')),
                                        DropdownMenuItem(
                                            value: 'ongoing',
                                            child: Text('Ongoing')),
                                        DropdownMenuItem(
                                            value: 'live', child: Text('Live')),
                                        DropdownMenuItem(
                                            value: 'completed',
                                            child: Text('Completed')),
                                        DropdownMenuItem(
                                            value: 'recorded',
                                            child: Text('Recorded')),
                                        DropdownMenuItem(
                                            value: 'cancelled',
                                            child: Text('Cancelled')),
                                      ],
                                      onChanged: (val) => setDialogState(() =>
                                          selectedStatus = val ?? 'scheduled'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Scheduled Time',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDateTime,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null && context.mounted) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      TimeOfDay.fromDateTime(selectedDateTime),
                                );
                                if (time != null) {
                                  setDialogState(() {
                                    selectedDateTime = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  });
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: Colors.white54, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedDateTime.toString().split('.')[0],
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Duration (min)',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: durationController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Meeting / Recording URL',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: linkController,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final link = linkController.text.trim();
                          final duration =
                              int.tryParse(durationController.text.trim()) ??
                                  60;

                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('⚠️ Title is required')),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          setDialogState(() => isSubmitting = true);

                          try {
                            final updates = {
                              'title': title,
                              'target_class': selectedClass,
                              'subject': selectedSubject,
                              'scheduled_at':
                                  selectedDateTime.toIso8601String(),
                              'duration_minutes': duration,
                              'status': selectedStatus,
                              'platform': selectedPlatform,
                              if (selectedStatus == 'recorded' ||
                                  selectedStatus == 'completed')
                                'recording_url': link.isEmpty
                                    ? 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
                                    : link
                              else
                                'meeting_link': link,
                            };

                            await _apiService.patchLiveClass(
                                liveClass.id, updates);

                            navigator.pop();
                            _loadLiveClasses();

                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFF10B981),
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Live class updated successfully!',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('❌ Error: $e')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TeacherLiveBroadcastingScreen extends StatefulWidget {
  final TeacherLiveClass liveClass;

  const _TeacherLiveBroadcastingScreen({required this.liveClass});

  @override
  State<_TeacherLiveBroadcastingScreen> createState() =>
      _TeacherLiveBroadcastingScreenState();
}

class _TeacherLiveBroadcastingScreenState
    extends State<_TeacherLiveBroadcastingScreen> {
  final TeacherApiService _apiService = TeacherApiService();
  List<Map<String, dynamic>> _comments = [];
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSharing = false;
  bool _isEnding = false;
  final int _viewers = 35;

  final TextEditingController _replyController = TextEditingController();
  Map<String, dynamic>? _pinnedComment;
  Timer? _commentsTimer;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _commentsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadComments();
    });
  }

  @override
  void dispose() {
    _commentsTimer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _apiService.getComments(widget.liveClass.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          final pinned =
              comments.firstWhere((c) => c['pinned'] == true, orElse: () => {});
          if (pinned.isNotEmpty) {
            _pinnedComment = pinned;
          } else {
            _pinnedComment = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _postTeacherReply({bool pin = false}) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    try {
      final res = await _apiService.postComment(widget.liveClass.id, text,
          isPinned: pin);
      if (res != null) {
        _replyController.clear();
        _loadComments();
      }
    } catch (_) {}
  }

  Future<void> _endLiveClass() async {
    setState(() => _isEnding = true);
    try {
      await _apiService.patchLiveClass(widget.liveClass.id, {
        "status": "recorded",
        "recording_url": (widget.liveClass.platform.toLowerCase() == 'in-app' ||
                widget.liveClass.platform.toLowerCase() == 'edushamiit' ||
                widget.liveClass.meetingLink == 'In-App' ||
                widget.liveClass.meetingLink == null)
            ? "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
            : (widget.liveClass.meetingLink ??
                "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('✅ Session ended. Recording saved successfully.'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isEnding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error ending session: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.liveClass.title,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.liveClass.subject} · ${widget.liveClass.class_}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // LIVE badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Viewers
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '👥 $_viewers',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Video/Camera Viewport area
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    color: Colors.black,
                    width: double.infinity,
                    child: Center(
                      child: _isVideoOff
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_off,
                                    size: 64, color: Colors.white38),
                                SizedBox(height: 8),
                                Text(
                                  'Camera is Off',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                // Mock Camera background / screen share preview
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF0C4A6E),
                                        Color(0xFF0369A1)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '👩‍🏫',
                                      style: TextStyle(fontSize: 80),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isSharing
                                          ? 'Screen Share Active'
                                          : 'Broadcasting Live Video',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'EduSHAMIIT Broadcasting Studio',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Overlay for Screen Share Active
                  if (_isSharing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.indigo.withValues(alpha: 0.9),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.screen_share,
                                  size: 64, color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'You are sharing your screen',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Students see your active presentations',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Pinned Comment Banner in player!
                  if (_pinnedComment != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 6)
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📌', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_pinnedComment!['user']} (${_pinnedComment!['role'].toString().toUpperCase()})',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _pinnedComment!['text'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Live Chat Area
            Expanded(
              flex: 3,
              child: Container(
                color: const Color(0xFF1E293B),
                child: Column(
                  children: [
                    // Chat header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 14, color: Colors.white70),
                          const SizedBox(width: 6),
                          const Text(
                            'Live Comments Feed',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70),
                          ),
                          const Spacer(),
                          Text(
                            '${_comments.length} comments',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),

                    // Comments List
                    Expanded(
                      child: _comments.isEmpty
                          ? const Center(
                              child: Text(
                                'No comments yet. Students will appear here.',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                final isTeacher = comment['role'] == 'teacher';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF334155),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            comment['user'] != null &&
                                                    comment['user'].isNotEmpty
                                                ? comment['user'][0]
                                                : '👤',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  comment['user'] ?? 'User',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isTeacher
                                                        ? const Color(
                                                            0xFF34D399)
                                                        : const Color(
                                                            0xFFA78BFA),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'Just now',
                                                  style: TextStyle(
                                                      fontSize: 8,
                                                      color: Colors.white38),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              comment['text'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Input Field & Announcement Post option
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        border: Border(top: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Post announcement / reply...',
                                hintStyle: const TextStyle(
                                    color: Colors.white30, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Post Announcement Button (Pins the message instantly)
                          IconButton(
                            icon: const Icon(Icons.push_pin,
                                color: Color(0xFF818CF8), size: 20),
                            tooltip: 'Pin Announcement',
                            onPressed: () => _postTeacherReply(pin: true),
                          ),
                          // Regular send button
                          IconButton(
                            icon: const Icon(Icons.send,
                                color: Color(0xFF10B981), size: 20),
                            onPressed: () => _postTeacherReply(pin: false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom studio control bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Mute Mic
                  _buildStudioControlBtn(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red : Colors.white24,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  // Video camera toggle
                  _buildStudioControlBtn(
                    icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                    color: _isVideoOff ? Colors.red : Colors.white24,
                    onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                  ),
                  // Screen Share
                  _buildStudioControlBtn(
                    icon: Icons.screen_share,
                    color:
                        _isSharing ? const Color(0xFF4F46E5) : Colors.white24,
                    onTap: () => setState(() => _isSharing = !_isSharing),
                  ),
                  // End Class Button (saves recording)
                  ElevatedButton(
                    onPressed: _isEnding ? null : _endLiveClass,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isEnding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'End Session',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioControlBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
