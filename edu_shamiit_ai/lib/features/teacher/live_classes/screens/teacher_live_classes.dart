import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherLiveClasses extends StatefulWidget {
  const TeacherLiveClasses({super.key});

  @override
  State<TeacherLiveClasses> createState() => _TeacherLiveClassesState();
}

class _TeacherLiveClassesState extends State<TeacherLiveClasses> {
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
      final status = _selectedStatus == 'All' ? null : _selectedStatus.toLowerCase();
      final liveClasses = await _apiService.getLiveClasses(status: status);
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
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
                colors: [Color(0xFFEF4444), Color(0xFFF87171)],
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
                  icon: const Icon(Icons.video_call, color: Colors.white),
                  onPressed: () => _showScheduleDialog(),
                ),
              ],
            ),
          ),

          // Status filter
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                final status = _statuses[index];
                final isSelected = _selectedStatus == status;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedStatus = status);
                    _loadLiveClasses();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error state
          if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadLiveClasses,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Live classes list
          if (!_isLoading && _error == null)
            Expanded(
              child: _liveClasses.isEmpty
                  ? const Center(child: Text('No live classes found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _liveClasses.length,
                      itemBuilder: (context, index) {
                        return _buildLiveClassCard(_liveClasses[index]);
                      },
                    ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showScheduleDialog(),
        backgroundColor: const Color(0xFFEF4444),
        icon: const Icon(Icons.video_call, color: Colors.white),
        label: const Text(
          'Schedule',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveClassCard(TeacherLiveClass liveClass) {
    final statusColor = _getStatusColor(liveClass.status);
    final isOngoing = liveClass.status.toLowerCase() == 'ongoing';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOngoing ? statusColor.withOpacity(0.5) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isOngoing
            ? [BoxShadow(color: statusColor.withOpacity(0.2), blurRadius: 12)]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  liveClass.title,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isOngoing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
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
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                liveClass.scheduledAt.toString().split('.')[0],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.class_, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Class ${liveClass.class_}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            liveClass.subject,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (isOngoing)
            ElevatedButton.icon(
              onPressed: () {
                // Join meeting
              },
              icon: const Icon(Icons.video_call),
              label: const Text('Join Meeting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _showScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Live Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Class'),
                items: ['X-A', 'X-B', 'X-C']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 12),
              TextField(decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Scheduled Time',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(hours: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Live class scheduled!')),
              );
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }
}