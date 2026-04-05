import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentEvents extends ConsumerStatefulWidget {
  const StudentEvents({super.key});

  @override
  ConsumerState<StudentEvents> createState() => _StudentEventsState();
}

class _StudentEventsState extends ConsumerState<StudentEvents> {
  String _selectedFilter = 'Upcoming';
  final List<String> _filters = ['Upcoming', 'Registered', 'Past'];
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _events = [
        {
          "id": "event-1",
          "title": "🏃 Annual Sports Day",
          "date": "April 5, 2025",
          "time": "8:00 AM",
          "venue": "Sports Ground",
          "description": "100m Sprint, Long Jump, Relay Race, Cricket & Badminton.",
          "gradient": const [Color(0xFF4F46E5), Color(0xFF06B6D4)],
          "status": "registered",
          "registered": true,
        },
        {
          "id": "event-2",
          "title": "🔬 Science Exhibition 2025",
          "date": "April 10, 2025",
          "venue": "School Hall",
          "description": "Top 3 winners get scholarships. Open to all classes.",
          "gradient": const [Color(0xFF059669), Color(0xFFF59E0B)],
          "status": "upcoming",
          "registered": false,
        },
        {
          "id": "event-3",
          "title": "🎤 Inter-School Debate",
          "date": "April 15, 2025",
          "venue": "Auditorium",
          "description": "Annual debate competition with schools from across the city.",
          "gradient": const [Color(0xFFD97706), Color(0xFFB45309)],
          "status": "upcoming",
          "registered": false,
        },
      ];
      _isLoading = false;
    });
  }

  List<dynamic> get _filteredEvents {
    if (_selectedFilter == 'Upcoming') {
      return _events.where((e) => e['status'] == 'upcoming' || e['status'] == 'registered').toList();
    } else if (_selectedFilter == 'Registered') {
      return _events.where((e) => e['registered'] == true).toList();
    }
    return _events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F5),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF831843), Color(0xFFBE185D)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Events',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🤖', style: TextStyle(fontSize: 10)),
                      SizedBox(width: 4),
                      Text(
                        'Suggest',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: List.generate(_filters.length, (index) {
                final isSelected = _filters[index] == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = _filters[index]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFBE185D) : const Color(0xFFFFF1F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFBE185D),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(_filteredEvents[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/student/aichat'),
        backgroundColor: const Color(0xFF4F46E5),
        child: const Text('🤖', style: TextStyle(fontSize: 20)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final gradient = event['gradient'] as List<Color>;
    final isRegistered = event['registered'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header image area
            Container(
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Text(
                      event['title'],
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Container(
              padding: const EdgeInsets.all(12),
              color: StudentColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildInfoChip('📅 ${event['date']}'),
                      if (event['time'] != null) ...[
                        const SizedBox(width: 6),
                        _buildInfoChip('⏰ ${event['time']}'),
                      ],
                      const SizedBox(width: 6),
                      _buildInfoChip('📍 ${event['venue']}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event['description'],
                    style: TextStyle(
                      fontSize: 10.5,
                      color: StudentColors.text3,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isRegistered)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '✅ Already Registered',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showRegistrationSuccess(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '🎯 Register Now',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Text('📤', style: TextStyle(fontSize: 14)),
                          onPressed: () {},
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
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

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem('🏠', 'Home', false, () => context.go('/student/dashboard')),
          _buildNavItem('📢', 'Notices', false, () => context.go('/student/notices')),
          _buildNavItem('📅', 'Events', true, null),
          _buildNavItem('🏆', 'Achieve', false, () => context.go('/student/achievements')),
          _buildNavItem('👤', 'Profile', false, () => context.go('/student/profile')),
        ],
      ),
    );
  }

  Widget _buildNavItem(String icon, String label, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }

  void _showRegistrationSuccess(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 8),
            Text(
              'Registration Successful!',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You've been registered for the event. You'll receive a reminder 1 day before.",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Awesome!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}