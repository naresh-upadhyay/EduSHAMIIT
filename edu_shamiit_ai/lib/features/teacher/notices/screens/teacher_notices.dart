import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';

class TeacherNotices extends ConsumerStatefulWidget {
  const TeacherNotices({super.key});

  @override
  ConsumerState<TeacherNotices> createState() => _TeacherNoticesState();
}

class _TeacherNoticesState extends ConsumerState<TeacherNotices> {
  final TeacherApiService _apiService = TeacherApiService();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedTab = 'all'; // 'all', 'my', 'school', 'draft'
  List<TeacherNotice> _notices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notices = await _apiService.getNotices(
        tab: _selectedTab,
      );
      setState(() {
        _notices = notices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getNoticeColor(TeacherNotice notice, String currentUserId) {
    if (notice.isUrgent) {
      return const Color(0xFFEF4444); // Urgent red
    }
    if (notice.createdBy == currentUserId) {
      return const Color(0xFF0EA5E9); // My notices blue
    }
    return const Color(0xFF4F46E5); // School notice purple
  }

  Color _getNoticeBgColor(TeacherNotice notice, String currentUserId) {
    if (notice.isUrgent) {
      return const Color(0xFFFEF2F2);
    }
    if (notice.createdBy == currentUserId) {
      return const Color(0xFFE0F2FE);
    }
    return const Color(0xFFEEF2FF);
  }

  String _formatNoticeDate(TeacherNotice notice) {
    if (notice.status == 'draft') {
      return 'Draft';
    }
    if (notice.status == 'scheduled' && notice.scheduledAt != null) {
      final sat = notice.scheduledAt!;
      return 'Scheduled for ${sat.day}/${sat.month}/${sat.year} ${sat.hour.toString().padLeft(2, '0')}:${sat.minute.toString().padLeft(2, '0')}';
    }
    final pub = notice.publishDate;
    return 'Published by ${notice.createdByName ?? "Teacher"} · ${pub.day}/${pub.month}/${pub.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState.userData?['id'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB), // Cream notices background from mockup
      body: Column(
        children: [
          // Header styled with linear gradient matching mockup
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context) + 8, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF92400E), Color(0xFFD97706)], // Amber theme notices header
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Notices & Circulars',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Refresh',
                      onPressed: _loadNotices,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _openNoticeEditor(context, currentUserId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '+ Create',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chip tab row matching mockup active styling
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildTabChip('All', 'all'),
                const SizedBox(width: 8),
                _buildTabChip('My Notices', 'my'),
                const SizedBox(width: 8),
                _buildTabChip('School', 'school'),
                const SizedBox(width: 8),
                _buildTabChip('Drafts', 'draft'),
              ],
            ),
          ),

          // Notices List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadNotices,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: AzureGrid<TeacherNotice>(
                          title: 'Notice Board',
                          items: _notices,
                          onRefresh: _loadNotices,
                          searchMatcher: (item) =>
                              '${item.title} ${item.content} ${item.noticeType} ${item.createdByName ?? ""}',
                          filters: [
                            AzureGridFilter<TeacherNotice>(
                              label: 'Urgency',
                              options: const ['Urgent', 'Normal'],
                              filterFn: (item, option) {
                                if (option == 'Urgent') return item.isUrgent;
                                if (option == 'Normal') return !item.isUrgent;
                                return true;
                              },
                            ),
                            AzureGridFilter<TeacherNotice>(
                              label: 'Type',
                              options: const ['Event', 'Announcement', 'Holiday', 'General'],
                              filterFn: (item, option) =>
                                  item.noticeType.toLowerCase() == option.toLowerCase(),
                            ),
                          ],
                          columns: [
                            AzureGridColumn<TeacherNotice>(
                              label: 'Title & Content',
                              width: 300,
                              compare: (a, b) => a.title.compareTo(b.title),
                              cellBuilder: (item) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.content,
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            AzureGridColumn<TeacherNotice>(
                              label: 'Type & Urgency',
                              width: 140,
                              compare: (a, b) => a.noticeType.compareTo(b.noticeType),
                              cellBuilder: (item) {
                                final borderCol = _getNoticeColor(item, currentUserId);
                                final bgCol = _getNoticeBgColor(item, currentUserId);
                                return Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: bgCol,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.isUrgent ? '🚨 URGENT' : item.noticeType.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: borderCol,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            AzureGridColumn<TeacherNotice>(
                              label: 'Created By',
                              width: 120,
                              compare: (a, b) => (a.createdByName ?? '').compareTo(b.createdByName ?? ''),
                              cellBuilder: (item) => Text(item.createdByName ?? 'Teacher'),
                            ),
                            AzureGridColumn<TeacherNotice>(
                              label: 'Publish Date / Status',
                              width: 180,
                              compare: (a, b) => a.publishDate.compareTo(b.publishDate),
                              cellBuilder: (item) => Text(_formatNoticeDate(item)),
                            ),
                            AzureGridColumn<TeacherNotice>(
                              label: 'Attachment',
                              width: 110,
                              cellBuilder: (item) {
                                if (item.attachmentUrl == null || item.attachmentUrl!.isEmpty) {
                                  return const Text('-');
                                }
                                return IconButton(
                                  icon: const Icon(Icons.attachment, size: 16, color: Color(0xFFD97706)),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Downloading ${item.attachmentUrl!.split('/').last} ...')),
                                    );
                                    getDownloadHelper().downloadFile(
                                      item.attachmentUrl!,
                                      item.attachmentUrl!.split('/').last,
                                    );
                                  },
                                  tooltip: 'Download attachment',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                );
                              },
                            ),
                            AzureGridColumn<TeacherNotice>(
                              label: 'Actions',
                              width: 130,
                              cellBuilder: (item) {
                                final isMyNotice = item.createdBy == currentUserId;
                                return Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _viewNoticeDetails(item),
                                      child: const Text('View', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                                    ),
                                    if (isMyNotice || item.status == 'draft')
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF64748B)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _openNoticeEditor(context, currentUserId, notice: item);
                                          } else if (value == 'delete') {
                                            _confirmDeleteNotice(item);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 14),
                                                SizedBox(width: 6),
                                                Text('Edit Notice', style: TextStyle(fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, size: 14, color: Colors.red),
                                                SizedBox(width: 6),
                                                Text('Delete Notice', style: TextStyle(color: Colors.red, fontSize: 11)),
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
                          mobileCardBuilder: (context, item) => _buildNoticeCard(item, currentUserId),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String value) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = value;
          });
          _loadNotices();
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD97706) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFFD97706),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeCard(TeacherNotice notice, String currentUserId) {
    final borderCol = _getNoticeColor(notice, currentUserId);
    final bgCol = _getNoticeBgColor(notice, currentUserId);
    final isMyNotice = notice.createdBy == currentUserId;

    return GestureDetector(
      onTap: () => _viewNoticeDetails(notice),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
          border: Border(
            left: BorderSide(
              color: borderCol,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row (Tags & Actions)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: bgCol,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notice.isUrgent ? '🚨 URGENT' : notice.noticeType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: borderCol,
                        ),
                      ),
                    ),
                    if (notice.noticeType.toLowerCase() == 'event') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '👥 ${notice.registrationCount} Registered',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                    if (notice.status == 'scheduled') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⏳ Scheduled',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isMyNotice || notice.status == 'draft')
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _openNoticeEditor(context, currentUserId, notice: notice),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text('✏️', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _confirmDeleteNotice(notice),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text('🗑️', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notice.title,
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notice.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📅 ${_formatNoticeDate(notice)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),
                if (notice.attachmentUrl != null && notice.attachmentUrl!.isNotEmpty)
                  const Text('📎', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewNoticeDetails(TeacherNotice notice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * (notice.noticeType.toLowerCase() == 'event' ? 0.82 : 0.70),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: notice.isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notice.isUrgent ? '🚨 URGENT' : notice.noticeType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: notice.isUrgent ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      notice.title,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      notice.content,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatNoticeDate(notice),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notice.attachmentUrl != null && notice.attachmentUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Downloading ${notice.attachmentUrl!.split('/').last} ...')),
                          );
                          getDownloadHelper().downloadFile(
                            notice.attachmentUrl!,
                            notice.attachmentUrl!.split('/').last,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.attachment, color: Color(0xFFD97706)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notice.attachmentUrl!.split('/').last,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Tap to download attachment',
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.download, color: Color(0xFFD97706)),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Downloading ${notice.attachmentUrl!.split('/').last} ...')),
                                  );
                                  getDownloadHelper().downloadFile(
                                    notice.attachmentUrl!,
                                    notice.attachmentUrl!.split('/').last,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (notice.noticeType.toLowerCase() == 'event') ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Registered Students (${notice.registrationCount})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Icon(Icons.people_outline, size: 18, color: Color(0xFFD97706)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _apiService.getNoticeRegistrations(notice.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Error loading registrants: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            );
                          }
                          final registrants = snapshot.data ?? [];
                          if (registrants.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: Text(
                                  'No student has registered for this event yet.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: registrants.length,
                            itemBuilder: (context, idx) {
                              final r = registrants[idx];
                              final name = r['full_name']?.toString() ?? 'Unknown Student';
                              final roll = r['roll_number']?.toString() ?? '';
                              final avatar = r['avatar_url']?.toString() ?? '';
                              final studentId = r['id']?.toString() ?? '';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFFFEF3C7),
                                      backgroundImage: avatar.isNotEmpty
                                          ? NetworkImage(avatar)
                                          : null,
                                      child: avatar.isEmpty
                                          ? Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFD97706),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (roll.isNotEmpty)
                                            Text(
                                              'Roll No: $roll',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (studentId.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chat_bubble_outline,
                                          color: Color(0xFFD97706),
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          context.push('/teacher/messaging?chat_id=$studentId');
                                        },
                                        tooltip: 'Send message',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteNotice(TeacherNotice notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: Text("Are you sure you want to delete '${notice.title}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final success = await _apiService.deleteNotice(notice.id);
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Notice deleted successfully')),
                  );
                  _loadNotices();
                } else {
                  throw Exception('Failed to delete notice');
                }
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openNoticeEditor(BuildContext context, String currentUserId, {TeacherNotice? notice}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NoticeEditorSheet(
        notice: notice,
        apiService: _apiService,
        onSaved: () {
          _loadNotices();
        },
      ),
    );
  }
}

class NoticeEditorSheet extends StatefulWidget {
  final TeacherNotice? notice;
  final TeacherApiService apiService;
  final VoidCallback onSaved;

  const NoticeEditorSheet({
    super.key,
    this.notice,
    required this.apiService,
    required this.onSaved,
  });

  @override
  State<NoticeEditorSheet> createState() => _NoticeEditorSheetState();
}

class _NoticeEditorSheetState extends State<NoticeEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _category;
  late String _targetAudience; // 'all' or 'class'
  late bool _isUrgent;
  late bool _isScheduled;
  DateTime? _scheduledDateTime;
  String? _attachmentUrl;
  bool _isSaving = false;

  List<TeacherMyClass> _availableClasses = [];
  List<String> _selectedClasses = [];
  bool _isLoadingClasses = false;
  String _classSearchQuery = '';
  final TextEditingController _classSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice?.title ?? '');
    _contentController = TextEditingController(text: widget.notice?.content ?? '');
    _category = widget.notice?.noticeType ?? 'General';
    // capitalize category to match database constraint
    if (_category.isNotEmpty) {
      _category = _category[0].toUpperCase() + _category.substring(1);
    }
    if (_category != 'Urgent' && _category != 'General' && _category != 'Event' && _category != 'Academic') {
      _category = 'General';
    }
    
    if (widget.notice != null) {
      _targetAudience = widget.notice!.targetAudience ?? 'all';
      if (_targetAudience != 'all' && _targetAudience != 'class') {
        // fallback if it was a single class name previously
        _selectedClasses = [_targetAudience];
        _targetAudience = 'class';
      } else {
        _selectedClasses = widget.notice!.targetClasses != null 
            ? List<String>.from(widget.notice!.targetClasses!) 
            : [];
      }
    } else {
      _selectedClasses = [];
      _targetAudience = 'all';
    }

    _isUrgent = widget.notice?.isUrgent ?? false;
    _isScheduled = widget.notice?.status == 'scheduled';
    _scheduledDateTime = widget.notice?.scheduledAt;
    _attachmentUrl = widget.notice?.attachmentUrl;

    _loadClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _classSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final classes = await widget.apiService.getMyClasses();
      setState(() {
        _availableClasses = classes;
      });
    } catch (e) {
      debugPrint('Error loading classes: $e');
    } finally {
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(minutes: 5)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime ?? DateTime.now()),
    );
    if (time == null) return;
    if (!mounted) return;

    setState(() {
      _scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final filename = result.files.single.name;
      
      setState(() => _isSaving = true);
      try {
        final response = await ApiService().multipartPostBytes(
          '/documents/upload',
          bytes,
          filename,
          'file',
          fields: {
            'title': filename,
            'category': 'school_notice',
            'description': 'Notice Attachment',
          },
        );
        if (response['success'] == true) {
          final doc = response['data']['document'] as Map<String, dynamic>;
          final fileUrl = doc['file_url'] as String;
          setState(() {
            _attachmentUrl = fileUrl;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$filename Attached Successfully ✅', style: const TextStyle(color: Colors.greenAccent))),
          );
        } else {
          throw Exception(response['detail'] ?? 'Upload failed');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload attachment: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    
    final finalStatus = _isScheduled && status == 'published' ? 'scheduled' : status;
    if (finalStatus == 'scheduled' && _scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select schedule date and time')),
      );
      return;
    }

    if (_targetAudience == 'class' && _selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one targeted class')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      bool success;
      if (widget.notice != null) {
        success = await widget.apiService.updateNotice(
          noticeId: widget.notice!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _category,
          status: finalStatus,
          isUrgent: _isUrgent,
          scheduledAt: finalStatus == 'scheduled' ? _scheduledDateTime?.toIso8601String() : null,
          targetAudience: _targetAudience,
          attachmentUrl: _attachmentUrl,
          targetClasses: _targetAudience == 'class' ? _selectedClasses : null,
        );
      } else {
        success = await widget.apiService.createNotice(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _category,
          status: finalStatus,
          isUrgent: _isUrgent,
          scheduledAt: finalStatus == 'scheduled' ? _scheduledDateTime?.toIso8601String() : null,
          targetAudience: _targetAudience,
          attachmentUrl: _attachmentUrl,
          targetClasses: _targetAudience == 'class' ? _selectedClasses : null,
        );
      }

      if (success) {
        widget.onSaved();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice ${widget.notice != null ? "updated" : "created"} successfully')),
        );
      } else {
        throw Exception('Failed to save notice');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredClasses = _availableClasses
        .where((c) => c.name.toLowerCase().contains(_classSearchQuery.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Text(
              widget.notice != null ? '✏️ Edit Notice' : '📢 Create Notice',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  const Text('Title', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Notice title...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),

                  const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    items: const [
                      DropdownMenuItem(value: 'General', child: Text('General')),
                      DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                      DropdownMenuItem(value: 'Event', child: Text('Event')),
                      DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Target Audience', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.language, size: 16),
                              SizedBox(width: 6),
                              Text('Entire School'),
                            ],
                          ),
                          selected: _targetAudience == 'all',
                          onSelected: (val) {
                            if (val) setState(() => _targetAudience = 'all');
                          },
                          selectedColor: const Color(0xFFFEF3C7),
                          checkmarkColor: const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.class_, size: 16),
                              SizedBox(width: 6),
                              Text('Specific Classes'),
                            ],
                          ),
                          selected: _targetAudience == 'class',
                          onSelected: (val) {
                            if (val) setState(() => _targetAudience = 'class');
                          },
                          selectedColor: const Color(0xFFFEF3C7),
                          checkmarkColor: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  if (_targetAudience == 'class') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _classSearchController,
                      onChanged: (val) {
                        setState(() {
                          _classSearchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search classes...',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: _classSearchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _classSearchController.clear();
                                  setState(() {
                                    _classSearchQuery = '';
                                  });
                                },
                                child: const Icon(Icons.clear, size: 16),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingClasses)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: filteredClasses.map((c) {
                          final isSelected = _selectedClasses.contains(c.name);
                          return FilterChip(
                            label: Text(c.name, style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xFF92400E) : Colors.black87)),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedClasses.add(c.name);
                                } else {
                                  _selectedClasses.remove(c.name);
                                }
                              });
                            },
                            selectedColor: const Color(0xFFFEF3C7),
                            checkmarkColor: const Color(0xFFD97706),
                          );
                        }).toList(),
                      ),
                      if (filteredClasses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No classes found', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ],
                  const SizedBox(height: 12),

                  const Text('Content', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Notice content...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Content is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Urgent checkbox
                  CheckboxListTile(
                    title: const Text('Mark as Urgent 🚨', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w700)),
                    value: _isUrgent,
                    onChanged: (val) {
                      if (val != null) setState(() => _isUrgent = val);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Schedule toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📅 Schedule for later', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Switch(
                        value: _isScheduled,
                        onChanged: (val) {
                          setState(() {
                            _isScheduled = val;
                          });
                        },
                        activeThumbColor: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                  if (_isScheduled) ...[
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _selectDateTime,
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(_scheduledDateTime == null
                          ? 'Select Date & Time'
                          : '${_scheduledDateTime!.day}/${_scheduledDateTime!.month}/${_scheduledDateTime!.year} at ${_scheduledDateTime!.hour.toString().padLeft(2, '0')}:${_scheduledDateTime!.minute.toString().padLeft(2, '0')}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFD97706)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Real file attachment box
                  GestureDetector(
                    onTap: _pickAttachment,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.attachment, size: 24, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            _attachmentUrl != null 
                                ? '${_attachmentUrl!.split("/").last} Attached ✅' 
                                : 'Attach Files (optional)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _attachmentUrl != null ? Colors.green : Colors.black87,
                            ),
                          ),
                          const Text(
                            'PDF, JPG or DOC up to 5MB',
                            style: TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _save('published'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('📤 Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _save('draft'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF334155),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('💾 Save Draft', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
