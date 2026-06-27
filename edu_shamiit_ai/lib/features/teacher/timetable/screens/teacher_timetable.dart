import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/calendar_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class TeacherTimetable extends ConsumerStatefulWidget {
  const TeacherTimetable({super.key});

  @override
  ConsumerState<TeacherTimetable> createState() => _TeacherTimetableState();
}

class _TeacherTimetableState extends ConsumerState<TeacherTimetable> {
  final TeacherApiService _apiService = TeacherApiService();

  DateTime _selectedDate = DateTime.now();
  List<TeacherTimetablePeriod> _allPeriods = [];
  List<TeacherTimetablePeriod> _periods = [];
  bool _isLoading = true;
  String? _error;

  // Class filter options
  String _selectedClassFilter = 'All';
  List<String> _classFilters = ['All'];
  List<String> _myClasses = [];
  TeacherProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _apiService.getProfile(),
        _apiService.getMyClasses(),
      ]);
      final profile = results[0] as TeacherProfile;
      final myClassesList = results[1] as List<TeacherMyClass>;

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _myClasses = myClassesList
            .map((c) {
              final section = c.section.trim();
              if (section.isEmpty || c.name.contains('-$section'))
                return c.name;
              return '${c.name}-$section';
            })
            .where((name) => name.isNotEmpty)
            .toList();
        final allClasses = {...profile.classes, ..._myClasses};
        final sortedClasses = allClasses.toList()..sort();
        _classFilters = ['All', ...sortedClasses];
      });
    } catch (_) {
      // Fallback
      try {
        final profile = await _apiService.getProfile();
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _classFilters = ['All', ...profile.classes];
        });
      } catch (_) {}
    }
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final periods = await _apiService.getTimetable(date: dateStr);
      if (!mounted) return;
      setState(() {
        _allPeriods = periods;
        // Dynamically add unique classes from timetable (primary source) + profile classes + myClasses
        final uniqueClasses = periods
            .map((p) => p.class_)
            .where((c) => c.isNotEmpty && c != 'All' && c != 'All Classes')
            .toSet();
        final profileClasses =
            (_profile?.classes ?? []).where((c) => c.isNotEmpty).toSet();
        final allClasses = {...profileClasses, ..._myClasses, ...uniqueClasses};
        final sortedClasses = allClasses.toList()..sort();
        _classFilters = ['All', ...sortedClasses];

        // If current filter is no longer valid, reset to All
        if (!_classFilters.contains(_selectedClassFilter)) {
          _selectedClassFilter = 'All';
        }
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    if (_selectedClassFilter == 'All') {
      _periods = List.from(_allPeriods);
    } else {
      _periods = _allPeriods
          .where((p) =>
              p.class_.toLowerCase() == _selectedClassFilter.toLowerCase())
          .toList();
    }
    // Sort by start time
    _periods.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> _selectDate(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumCalendarPicker(
        initialDate: _selectedDate,
        primaryColor: const Color(0xFF0EA5E9),
        onDateSelected: (date) {
          setState(() {
            _selectedDate = date;
          });
          _loadTimetable();
        },
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    const weekdays = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return "${weekdays[date.weekday]}, ${months[date.month]} ${date.day}";
  }

  String _getWeekdayAbbr(int weekday) {
    const days = ['', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // Header Gradient matching Mockup style
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () =>
                          safeGoBack(context, '/teacher/dashboard'),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'My Timetable',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Select Date'.tr(ref),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 22),
                      tooltip: 'Schedule',
                      onPressed: _showScheduleModal,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatFullDate(_selectedDate),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 12),

                // Weekly horizontal date chips (Mockup design: MON 24, TUE 25...)
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final offset = index - 3;
                      final dateOfChoice =
                          _selectedDate.add(Duration(days: offset));
                      final isSelected = offset == 0;
                      final dayName = _getWeekdayAbbr(dateOfChoice.weekday);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = dateOfChoice;
                          });
                          _loadTimetable();
                        },
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 54),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(colors: [
                                    Color(0xFF0EA5E9),
                                    Color(0xFF06B6D4)
                                  ])
                                : null,
                            color: isSelected
                                ? null
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dateOfChoice.day}',
                                style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Class filter tabs — always show when data loaded
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: _classFilters.map((cls) {
                  final isSelected = cls == _selectedClassFilter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedClassFilter = cls;
                        _applyFilters();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E40AF)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark ? Colors.white12 : Colors.grey[300]!),
                        ),
                        boxShadow: isSelected
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Text(
                        cls == 'All' ? 'All Classes' : 'Class $cls',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Main schedule view
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
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
                              onPressed: _loadTimetable,
                              child: Text('Retry'.tr(ref)),
                            ),
                          ],
                        ),
                      )
                    : _periods.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🏖️',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedDate.weekday == 7
                                      ? 'No Classes Today (Sunday)'
                                      : 'No classes scheduled',
                                  style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enjoy your rest day!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white30
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
                            itemCount: _periods.length,
                            itemBuilder: (context, index) {
                              return _buildPeriodCard(_periods[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(TeacherTimetablePeriod period) {
    final isLiveClass = period.periodNumber == 'Live Class';
    final isEvent = period.periodNumber == 'Event';
    final isNow = _isPeriodNow(period.startTime, period.endTime);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color accent = const Color(0xFF0EA5E9);

    if (isLiveClass) {
      bg = isDark ? const Color(0xFF2E1A47) : const Color(0xFFF5F3FF);
      border = isDark ? const Color(0xFF4C1D95) : const Color(0xFFDDD6FE);
      accent = const Color(0xFF8B5CF6);
    } else if (isEvent) {
      bg = isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
      border = isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
      accent = const Color(0xFFF59E0B);
    }

    if (isNow) {
      bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      border = isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0);
      accent = const Color(0xFF059669);
    }

    return GestureDetector(
      onTap: () => _showPeriodDetail(period),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Stack(
          children: [
            // Left indicator line
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(4)),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  // Time info
                  SizedBox(
                    width: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          period.startTime.substring(0, 5),
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isNow
                                ? accent
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A)),
                          ),
                        ),
                        Text(
                          period.endTime.substring(0, 5),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white30 : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dot separator
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Period Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          period.subject,
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLiveClass || isEvent
                              ? 'Type: ${period.periodNumber}'
                              : 'Class ${period.class_}  •  Period ${period.periodNumber}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Room / Now badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (period.roomNumber != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            period.roomNumber!,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      if (isNow) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'NOW',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
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
    );
  }

  void _showPeriodDetail(TeacherTimetablePeriod period) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('📅', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period.subject,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Class ${period.class_} Schedule',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                      'Time:', '${period.startTime} – ${period.endTime}'),
                  _buildDetailRow('Room/Location:', period.roomNumber ?? 'N/A'),
                  _buildDetailRow('Period Type:', period.periodNumber),
                  _buildDetailRow('Teacher:', period.teacherName ?? 'You'),
                  if (period.periodNumber == 'Live Class') ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'This is a scheduled digital class meeting. Students can join online via their student portal schedule.',
                      style:
                          TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (period.periodNumber == 'Live Class') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _startOrJoinLiveClass(period);
                      },
                      icon: const Icon(Icons.video_call, color: Colors.white),
                      label: const Text(
                        'Start / Join',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: period.periodNumber == 'Live Class'
                          ? (isDark ? Colors.grey[800] : Colors.grey[200])
                          : const Color(0xFF1E40AF),
                      foregroundColor: period.periodNumber == 'Live Class'
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(period.periodNumber == 'Live Class'
                        ? 'Dismiss'
                        : 'Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMeeting(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $e')),
      );
    }
  }

  void _startOrJoinLiveClass(TeacherTimetablePeriod period) async {
    final statusLower = (period.status ?? 'scheduled').toLowerCase();
    final isLive = statusLower == 'ongoing' || statusLower == 'live';
    final platformLower = (period.platform ?? 'In-App').toLowerCase();
    final meetingLink = period.meetingLink ?? '';

    final auth = ref.read(authProvider);

    if (platformLower == 'in-app' || platformLower == 'edushamiit') {
      if (!isLive) {
        try {
          await _apiService.patchLiveClass(period.id, {
            "status": "live",
          });
        } catch (_) {}
      }

      if (!mounted) return;
      context.push(
        '/live-room',
        extra: {
          'liveClassId': period.id,
          'currentUserId': auth.userData?['id'] ?? '',
          'currentUserName': auth.userData?['full_name'] ?? 'Teacher',
          'currentUserRole': 'teacher',
          'title': period.subject.replaceAll('💻 Live Class: ', ''),
        },
      ).then((_) => _loadTimetable());
    } else {
      if (!isLive) {
        try {
          await _apiService.patchLiveClass(period.id, {
            "status": "live",
          });
        } catch (_) {}
      }
      if (meetingLink.isNotEmpty && meetingLink != 'In-App') {
        _launchMeeting(meetingLink);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No meeting link available.')),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleModal() {
    final subjectController = TextEditingController();
    final roomController = TextEditingController();
    final liveLinkController = TextEditingController(text: 'In-App');
    String typeFilter = 'Extra Class';
    String classFilter = _classFilters.length > 1 ? _classFilters[1] : 'X-A';
    String livePlatform = 'In-App';
    DateTime selectedModalDate = _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF192231) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Schedule Class Meeting',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Meeting type Dropdown
                  const Text('Meeting Type',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: typeFilter,
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    items: [
                      'Extra Class',
                      'Parent-Teacher Meeting',
                      'Staff Meeting',
                      'Live Class'
                    ]
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => typeFilter = val);
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Class Dropdown
                  const Text('Class Target',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: classFilter,
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    items: _classFilters
                        .where((c) => c != 'All')
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text('Class $c')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => classFilter = val);
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subject TextField
                  const Text('Subject/Topic',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: subjectController,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'e.g. Calculus Ch.7',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Platform and Link for Live Class
                  if (typeFilter == 'Live Class') ...[
                    const Text('Platform',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: livePlatform,
                      dropdownColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      items: ['In-App', 'Zoom', 'Google Meet', 'YouTube']
                          .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            livePlatform = val;
                            if (livePlatform == 'In-App') {
                              liveLinkController.text = 'In-App';
                            } else if (livePlatform == 'Zoom') {
                              liveLinkController.text =
                                  'https://zoom.us/j/1234567890';
                            } else if (livePlatform == 'Google Meet') {
                              liveLinkController.text =
                                  'https://meet.google.com/abc-defg-hij';
                            } else if (livePlatform == 'YouTube') {
                              liveLinkController.text =
                                  'https://www.youtube.com/embed/dQw4w9WgXcQ';
                            }
                          });
                        }
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (livePlatform != 'In-App') ...[
                      const Text('Meeting Link',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: liveLinkController,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'e.g. https://meet.google.com/...',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  // Date Picker Field
                  const Text('Date',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedModalDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: const Color(0xFF1E40AF),
                                onPrimary: Colors.white,
                                onSurface: isDark ? Colors.white : Colors.black,
                              ),
                              dialogTheme: DialogThemeData(
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setModalState(() => selectedModalDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDark ? Colors.white24 : Colors.grey[350]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Color(0xFF1E40AF)),
                          const SizedBox(width: 8),
                          Text(
                            "${selectedModalDate.year}-${selectedModalDate.month.toString().padLeft(2, '0')}-${selectedModalDate.day.toString().padLeft(2, '0')}",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Time fields
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                    context: context, initialTime: startTime);
                                if (time != null) {
                                  setModalState(() => startTime = time);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey[350]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                    context: context, initialTime: endTime);
                                if (time != null) {
                                  setModalState(() => endTime = time);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey[350]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Room TextField
                  const Text('Room/Location',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: roomController,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'e.g. Room 301, Staff Room',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (subjectController.text.trim().isEmpty) return;

                        final startStr =
                            "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00";
                        final endStr =
                            "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00";
                        final dateStr =
                            "${selectedModalDate.year}-${selectedModalDate.month.toString().padLeft(2, '0')}-${selectedModalDate.day.toString().padLeft(2, '0')}";

                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);

                        setState(() {
                          _isLoading = true;
                        });

                        try {
                          if (typeFilter == 'Live Class') {
                            final scheduledAt = DateTime(
                              selectedModalDate.year,
                              selectedModalDate.month,
                              selectedModalDate.day,
                              startTime.hour,
                              startTime.minute,
                            );
                            final startMinutes =
                                startTime.hour * 60 + startTime.minute;
                            final endMinutes =
                                endTime.hour * 60 + endTime.minute;
                            int duration = endMinutes - startMinutes;
                            if (duration <= 0) duration = 60;

                            final link = liveLinkController.text.trim();

                            await _apiService.createLiveClass(
                              title: subjectController.text.trim(),
                              classId: classFilter,
                              subject: subjectController.text.trim(),
                              scheduledAt: scheduledAt,
                              durationMinutes: duration,
                              status: 'scheduled',
                              streamUrl:
                                  livePlatform == 'In-App' ? 'In-App' : link,
                              recordingUrl: null,
                              platform: livePlatform,
                              meetingLink:
                                  livePlatform == 'In-App' ? 'In-App' : link,
                            );
                          }

                          await _apiService.scheduleTimetableSlot(
                            date: dateStr,
                            slotType: typeFilter,
                            customSubject: subjectController.text,
                            classId: classFilter,
                            startTime: startStr,
                            endTime: endStr,
                            room: roomController.text.isNotEmpty
                                ? roomController.text
                                : (typeFilter == 'Live Class'
                                    ? (livePlatform == 'In-App'
                                        ? 'In-App Live Room'
                                        : livePlatform)
                                    : 'Room 101'),
                          );

                          setState(() {
                            _selectedDate = selectedModalDate;
                          });
                          await _loadTimetable();

                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content:
                                    Text('$typeFilter scheduled successfully!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Schedule Slot',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isPeriodNow(String startStr, String endStr) {
    try {
      final now = DateTime.now();
      final startTime = _parseTimeStringToTimeOfDay(startStr);
      final endTime = _parseTimeStringToTimeOfDay(endStr);

      if (startTime == null || endTime == null) return false;

      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;

      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } catch (_) {
      return false;
    }
  }

  TimeOfDay? _parseTimeStringToTimeOfDay(String timeStr) {
    try {
      var cleaned = timeStr.toUpperCase().replaceAll('Z', '').trim();
      bool isPM = cleaned.contains('PM');
      bool isAM = cleaned.contains('AM');
      cleaned = cleaned.replaceAll('AM', '').replaceAll('PM', '').trim();

      final parts = cleaned.split(':');
      if (parts.isEmpty) return null;

      var hour = int.parse(parts[0]);
      var minute = parts.length > 1 ? int.parse(parts[1].split(' ')[0]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }
}
