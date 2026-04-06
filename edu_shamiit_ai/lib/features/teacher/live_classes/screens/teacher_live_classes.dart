import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherLiveClasses extends StatefulWidget {
  const TeacherLiveClasses({super.key});

  @override
  State<TeacherLiveClasses> createState() => _TeacherLiveClassesState();
}

class _TeacherLiveClassesState extends State<TeacherLiveClasses> {
  String _selectedTab = 'Live';
  final List<String> _tabs = ['Live', 'Scheduled', 'Recorded'];

  final List<Map<String, dynamic>> _classes = [
    {
      'id': '1',
      'title': 'Trigonometry - Class X-A',
      'class': 'X-A',
      'subject': 'Mathematics',
      'status': 'live',
      'students': 38,
      'duration': '45 min',
      'startTime': DateTime.now().subtract(const Duration(minutes: 15)),
      'meetingId': '123-456-789',
    },
    {
      'id': '2',
      'title': 'Quadratic Equations - Class X-B',
      'class': 'X-B',
      'subject': 'Mathematics',
      'status': 'scheduled',
      'students': 0,
      'duration': '45 min',
      'startTime': DateTime.now().add(const Duration(hours: 2)),
      'meetingId': '987-654-321',
    },
    {
      'id': '3',
      'title': 'Physics - Laws of Motion',
      'class': 'IX-A',
      'subject': 'Physics',
      'status': 'recorded',
      'students': 35,
      'duration': '52 min',
      'startTime': DateTime.now().subtract(const Duration(days: 1)),
      'meetingId': '456-789-123',
      'recordingUrl': 'https://recordings.edushamiit.com/physics-motion',
    },
    {
      'id': '4',
      'title': 'Chemistry - Organic Compounds',
      'class': 'X-C',
      'subject': 'Chemistry',
      'status': 'recorded',
      'students': 40,
      'duration': '48 min',
      'startTime': DateTime.now().subtract(const Duration(days: 2)),
      'meetingId': '321-654-987',
      'recordingUrl': 'https://recordings.edushamiit.com/chemistry-organic',
    },
  ];

  List<Map<String, dynamic>> get _filteredClasses {
    return _classes.where((c) => c['status'] == _selectedTab.toLowerCase()).toList();
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getRelativeTime(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) {
      final days = (-diff.inDays);
      return '$days days ago';
    }
    if (diff.inHours < 1) return 'In ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'In ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'Tomorrow';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'live': return const Color(0xFFEF4444);
      case 'scheduled': return const Color(0xFF0EA5E9);
      case 'recorded': return const Color(0xFF059669);
      default: return Colors.grey;
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
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Live Classes',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  onPressed: () => _startInstantClass(),
                ),
              ],
            ),
          ),

          // Tabs
          SizedBox(
            height: 44,
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
                      color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Classes list
          Expanded(
            child: _filteredClasses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedTab == 'live' ? '📹' : _selectedTab == 'scheduled' ? '📅' : '🎬',
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedTab classes',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredClasses.length,
                    itemBuilder: (context, index) {
                      return _buildClassCard(_filteredClasses[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scheduleClass(),
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Schedule Class',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classInfo) {
    final status = classInfo['status'] as String;
    final statusColor = _getStatusColor(status);
    final isLive = status == 'live';
    final isRecorded = status == 'recorded';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? const Color(0xFFEF4444).withOpacity(0.3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLive
                        ? [const Color(0xFFEF4444), const Color(0xFFF87171)]
                        : isRecorded
                            ? [const Color(0xFF059669), const Color(0xFF10B981)]
                            : [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    isLive ? Icons.videocam : isRecorded ? Icons.play_circle : Icons.schedule,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classInfo['title'] as String,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${classInfo['class']} • ${classInfo['subject']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (isLive) const SizedBox(width: 4),
                    Text(
                      isLive ? 'LIVE' : isRecorded ? 'RECORDED' : _getRelativeTime(classInfo['startTime'] as DateTime),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Info row
          Row(
            children: [
              Icon(Icons.people, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                isLive ? '${classInfo['students']} students' : '${classInfo['duration']}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                classInfo['duration'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                'ID: ${classInfo['meetingId']}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              if (isLive)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📹 Joining class...')),
                      );
                    },
                    icon: const Icon(Icons.videocam, size: 16),
                    label: const Text(
                      'Join Class',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (isRecorded) ...[
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text(
                      'Watch',
                      style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text(
                      'Download',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0EA5E9)),
                    ),
                  ),
                ),
              ],
              if (status == 'scheduled') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text(
                      'Start Now',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0EA5E9)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _startInstantClass() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Instant Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Class',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {},
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Topic',
                hintText: 'Enter class topic',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📹 Starting instant class...')),
              );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _scheduleClass() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Trigonometry - Class X-A',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        hintText: 'Select',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      readOnly: true,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Time',
                        hintText: 'Select',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      readOnly: true,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Duration',
                  hintText: 'e.g., 45 min',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Class scheduled successfully!')),
              );
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }
}