import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';

class StudentNotices extends ConsumerStatefulWidget {
  const StudentNotices({super.key});

  @override
  ConsumerState<StudentNotices> createState() => _StudentNoticesState();
}

class _StudentNoticesState extends ConsumerState<StudentNotices> {
  final StudentApiService _apiService = StudentApiService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Urgent', 'General', 'Event', 'Academic'];
  List<Notice> _allNotices = [];
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
      // Always fetch all notices from API without category filter
      // so we can do client-side search + category filtering
      final notices = await _apiService.getNotices();
      setState(() {
        _allNotices = notices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Notice> get _filteredNotices {
    var result = _allNotices;

    // Filter by category
    if (_selectedCategory != 'All') {
      final catKey = _selectedCategory.toLowerCase();
      result = result.where((n) {
        final nCat = n.category.toLowerCase();
        if (catKey == 'event') return nCat == 'event' || nCat == 'events';
        return nCat == catKey;
      }).toList();
    }

    // Filter by search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((n) {
        return n.title.toLowerCase().contains(query) ||
            n.content.toLowerCase().contains(query) ||
            (n.authorName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return result;
  }

  int get _urgentCount => _allNotices.where((n) => n.category.toLowerCase() == 'urgent').length;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'urgent':
        return StudentColors.error;
      case 'event':
      case 'events':
        return StudentColors.warning;
      case 'academic':
        return const Color(0xFF8B5CF6);
      case 'general':
      default:
        return StudentColors.primary;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'urgent':
        return '🚨 URGENT';
      case 'event':
      case 'events':
        return '🎉 EVENT';
      case 'academic':
        return '📋 ACADEMIC';
      case 'general':
      default:
        return '📋 GENERAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotices;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: Column(
        children: [
          // Header with search
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF92400E), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/student/dashboard'),
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
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Refresh',
                      onPressed: _loadNotices,
                    ),
                    if (_urgentCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: StudentColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_urgentCount urgent',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '🔍 Search notices...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Icon(Icons.close, color: Colors.white70, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          // Category Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = category);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFD97706) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Notices List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotices,
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
                                const Text('Failed to load notices', style: TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadNotices,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('📭', style: TextStyle(fontSize: 48)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'No notices match your search'
                                        : 'No notices in this category',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildNoticeCard(filtered[index]);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(Notice notice) {
    final color = _getColorForCategory(notice.category);
    final label = _getCategoryLabel(notice.category);

    return GestureDetector(
      onTap: () => _showNoticeDetail(notice),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
          border: Border(
            left: BorderSide(
              color: color,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                if (notice.category.toLowerCase() == 'event' || notice.category.toLowerCase() == 'events') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: notice.registered ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notice.registered ? '✓ Registered' : '🎉 Event',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: notice.registered ? const Color(0xFF065F46) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (notice.attachmentUrl != null && notice.attachmentUrl!.isNotEmpty)
                  const Text('📎', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notice.title,
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: StudentColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notice.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: StudentColors.text2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '📅 ${_formatDate(notice.createdAt)} · By ${notice.authorName ?? "School"}',
              style: const TextStyle(
                fontSize: 9,
                color: StudentColors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDetail(Notice notice) {
    final color = _getColorForCategory(notice.category);
    final label = _getCategoryLabel(notice.category);

    final contentLower = notice.content.toLowerCase();
    final titleLower = notice.title.toLowerCase();
    final isFeeNotice = contentLower.contains('fee') ||
        contentLower.contains('pay') ||
        contentLower.contains('payment') ||
        contentLower.contains('fine') ||
        titleLower.contains('fee') ||
        titleLower.contains('pay') ||
        titleLower.contains('payment') ||
        titleLower.contains('fine');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: StudentColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
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
                        color: StudentColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      notice.content,
                      style: const TextStyle(
                        fontSize: 13,
                        color: StudentColors.text2,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StudentColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: StudentColors.text3),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Published: ${_formatDate(notice.createdAt)} · By ${notice.authorName ?? "School"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: StudentColors.text3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notice.attachmentUrl != null && notice.attachmentUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Downloading ${notice.attachmentUrl!.split('/').last}...'),
                            ),
                          );
                          getDownloadHelper().downloadFile(
                            notice.attachmentUrl!,
                            notice.attachmentUrl!.split('/').last,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: StudentColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.attachment, color: StudentColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notice.attachmentUrl!.split('/').last,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: StudentColors.text,
                                      ),
                                    ),
                                    const Text(
                                      'Tap to download attachment',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: StudentColors.text3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.download, color: StudentColors.primary),
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Downloading ${notice.attachmentUrl!.split('/').last}...'),
                                    ),
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final isEvent = notice.category.toLowerCase() == 'event' || notice.category.toLowerCase() == 'events';
                  final isRegistered = notice.registered;

                  return Column(
                    children: [
                      if (isEvent) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isRegistered
                                ? null
                                : () async {
                                    setModalState(() {
                                      _isLoading = true;
                                    });
                                    try {
                                      final ok = await _apiService.registerForNotice(notice.id);
                                      if (ok) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Registered for Event Successfully! 🎉')),
                                          );
                                          Navigator.pop(context);
                                          _loadNotices();
                                        }
                                      } else {
                                        throw Exception('Failed to register');
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRegistered ? const Color(0xFF10B981) : const Color(0xFFD97706),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isRegistered ? Icons.check_circle : Icons.event_available, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  isRegistered ? 'Registered' : 'Register for Event',
                                  style: const TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (isFeeNotice) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push('/student/fees');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '💳 ',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  'Pay Now',
                                  style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StudentColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
