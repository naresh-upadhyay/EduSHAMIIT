import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';

class StudentEvents extends ConsumerStatefulWidget {
  const StudentEvents({super.key});

  @override
  ConsumerState<StudentEvents> createState() => _StudentEventsState();
}

class _StudentEventsState extends ConsumerState<StudentEvents> {
  final StudentApiService _apiService = StudentApiService();
  String _selectedFilter = 'Upcoming';
  final List<String> _filters = ['Upcoming', 'Registered', 'Past'];
  List<Event> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final filterMap = {
        'Upcoming': 'upcoming',
        'Registered': 'registered',
        'Past': 'past',
      };
      
      final filter = filterMap[_selectedFilter];
      final events = await _apiService.getEvents(filter: filter);
      
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Event> get _filteredEvents {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Upcoming':
        return _events.where((e) => e.startDate.isAfter(now) || e.isRegistered).toList();
      case 'Registered':
        return _events.where((e) => e.isRegistered).toList();
      case 'Past':
        return _events.where((e) => e.endDate.isBefore(now) && !e.isRegistered).toList();
      default:
        return _events;
    }
  }

  // Get gradient colors based on event type
  List<Color> _getGradientColors(String type) {
    switch (type.toLowerCase()) {
      case 'sports':
        return [const Color(0xFF4F46E5), const Color(0xFF06B6D4)];
      case 'academic':
        return [const Color(0xFF059669), const Color(0xFFF59E0B)];
      case 'cultural':
        return [const Color(0xFFD97706), const Color(0xFFB45309)];
      default:
        return [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)];
    }
  }

  // Get event icon based on type
  String _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sports':
        return '🏃';
      case 'academic':
        return '🔬';
      case 'cultural':
        return '🎤';
      default:
        return '📅';
    }
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
                    color: Colors.white.withValues(alpha: 0.15),
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
      

    );
  }

  Widget _buildEventCard(Event event) {
    final gradient = _getGradientColors(event.type);
    final isRegistered = event.isRegistered;
    final icon = _getEventIcon(event.type);
    final startDateStr = '${event.startDate.day}/${event.startDate.month}/${event.startDate.year}';
    final startTimeStr = '${event.startDate.hour}:${event.startDate.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
                      '$icon ${event.title}',
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
                      _buildInfoChip('📅 $startDateStr'),
                      const SizedBox(width: 6),
                      _buildInfoChip('⏰ $startTimeStr'),
                      const SizedBox(width: 6),
                      _buildInfoChip('📍 ${event.location}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    style: const TextStyle(
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
                            onPressed: () => _registerForEvent(event.id),
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

  Future<void> _registerForEvent(String eventId) async {
    try {
      final success = await _apiService.registerForEvent(eventId);
      if (mounted) {
        if (success) {
          _showRegistrationSuccess(context);
          _loadEvents(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to register for event'.tr(ref))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
            const Text(
              'Registration Successful!',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF059669),
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
                child: Text('Awesome!'.tr(ref)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
