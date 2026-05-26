import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentEvents extends ConsumerStatefulWidget {
  const StudentEvents({super.key});

  @override
  ConsumerState<StudentEvents> createState() => _StudentEventsState();
}

class _StudentEventsState extends ConsumerState<StudentEvents> {
  String _selectedTab = 'Upcoming';
  final List<String> _tabs = ['Upcoming', 'Registered', 'Past'];

  final List<Map<String, dynamic>> _events = [
    {
      'id': '1',
      'title': 'Annual Sports Day',
      'description': '100m Sprint, Long Jump, Relay Race, Cricket & Badminton. Participate and win exciting prizes!',
      'date': DateTime.now().add(const Duration(days: 10)),
      'time': '8:00 AM',
      'venue': 'School Ground',
      'gradient': const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
      ),
      'status': 'registered',
      'registered': true,
    },
    {
      'id': '2',
      'title': 'Science Exhibition 2025',
      'description': 'Top 3 winners get scholarships. Open to all classes. Project categories: Working Model, Chart, PowerPoint.',
      'date': DateTime.now().add(const Duration(days: 15)),
      'time': '9:00 AM',
      'venue': 'School Hall',
      'gradient': const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF06B6D4)],
      ),
      'status': 'upcoming',
      'registered': false,
    },
    {
      'id': '3',
      'title': 'Inter-School Debate',
      'description': 'Showcase your debating skills. Topics will be announced on the day of event.',
      'date': DateTime.now().add(const Duration(days: 20)),
      'time': '10:00 AM',
      'venue': 'Auditorium',
      'gradient': const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFB45309)],
      ),
      'status': 'upcoming',
      'registered': false,
    },
    {
      'id': '4',
      'title': 'Annual Cultural Fest',
      'description': 'Dance, Music, Drama, and more! Register for multiple events and showcase your talent.',
      'date': DateTime.now().add(const Duration(days: 30)),
      'time': '9:00 AM',
      'venue': 'School Campus',
      'gradient': const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
      ),
      'status': 'upcoming',
      'registered': false,
    },
    {
      'id': '5',
      'title': 'Quiz Competition',
      'description': 'General knowledge quiz for all classes. Team of 3 members allowed.',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'time': '11:00 AM',
      'venue': 'Library Hall',
      'gradient': const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      ),
      'status': 'past',
      'registered': false,
    },
  ];

  List<Map<String, dynamic>> get _filteredEvents {
    switch (_selectedTab) {
      case 'Registered':
        return _events.where((e) => e['registered'] == true).toList();
      case 'Past':
        return _events.where((e) => e['status'] == 'past').toList();
      default:
        return _events.where((e) => e['status'] == 'upcoming' || e['registered'] == true).toList();
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    
    if (diff.isNegative) return 'Completed';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return 'In ${diff.inDays} days';
    return _formatDate(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F5),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF831843), Color(0xFFBE185D)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Events',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        '??',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Suggest',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? StudentColors.error : const Color(0xFFFFF1F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : StudentColors.error,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Events List
          Expanded(
            child: _filteredEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '??',
                          style: TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedTab events',
                          style: const TextStyle(
                            fontSize: 14,
                            color: StudentColors.text3,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = _filteredEvents[index];
                      return _buildEventCard(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final isRegistered = event['registered'] as bool;
    final isPast = event['status'] == 'past';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event banner
          Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: event['gradient'] as LinearGradient,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Text(
                    event['title'] as String,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isRegistered)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Registered',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isPast)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Event details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildDetailItem(Icons.calendar_today, _getRelativeDate(event['date'] as DateTime)),
                    const SizedBox(width: 12),
                    _buildDetailItem(Icons.access_time, event['time'] as String),
                    const SizedBox(width: 12),
                    _buildDetailItem(Icons.location_on, event['venue'] as String),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event['description'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: StudentColors.text3,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (!isRegistered && !isPast)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _registerForEvent(event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBE185D),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '?? Register Now',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else if (isRegistered)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showEventDetails(event),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text(
                            'View Details',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StudentColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showEventDetails(event),
                          icon: const Icon(Icons.info, size: 16),
                          label: const Text(
                            'View Details',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StudentColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      width: 38,
                      child: ElevatedButton(
                        onPressed: () => _shareEvent(event),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3C7),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '??',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: StudentColors.text3),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: StudentColors.text3,
          ),
        ),
      ],
    );
  }

  void _registerForEvent(Map<String, dynamic> event) {
    setState(() {
      event['registered'] = true;
      event['status'] = 'upcoming';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully registered for ${event['title']}!'),
        backgroundColor: StudentColors.success,
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
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
                    // Banner
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: event['gradient'] as LinearGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          event['title'] as String,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Details
                    _buildDetailRow(Icons.calendar_today, 'Date', _formatDate(event['date'] as DateTime)),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.access_time, 'Time', event['time'] as String),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.location_on, 'Venue', event['venue'] as String),
                    const SizedBox(height: 16),
                    const Text(
                      'About this event',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: StudentColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event['description'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: StudentColors.text2,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Close button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudentColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: StudentColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: StudentColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareEvent(Map<String, dynamic> event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing ${event['title']}...'),
        backgroundColor: StudentColors.primary,
      ),
    );
  }
}
