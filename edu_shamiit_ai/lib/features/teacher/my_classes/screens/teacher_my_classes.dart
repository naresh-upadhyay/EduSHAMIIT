import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherMyClasses extends StatefulWidget {
  const TeacherMyClasses({super.key});

  @override
  State<TeacherMyClasses> createState() => _TeacherMyClassesState();
}

class _TeacherMyClassesState extends State<TeacherMyClasses> {
  final TeacherApiService _apiService = TeacherApiService();
  
  List<TeacherMyClass> _classes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final classes = await _apiService.getMyClasses();
      setState(() {
        _classes = classes;
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
      backgroundColor: const Color(0xFFF0F9FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Classes',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
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
                      onPressed: _loadClasses,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Classes list
          if (!_isLoading && _error == null)
            Expanded(
              child: _classes.isEmpty
                  ? const Center(child: Text('No classes assigned'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _classes.length,
                      itemBuilder: (context, index) {
                        return _buildClassCard(_classes[index]);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassCard(TeacherMyClass class_) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.class_,
              color: Color(0xFF06B6D4),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          // Class name
          Text(
            '${class_.name} - ${class_.section}',
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          // Student count
          Row(
            children: [
              const Icon(Icons.people, size: 14, color: Color(0xFF06B6D4)),
              const SizedBox(width: 4),
              Text(
                '${class_.studentCount} students',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Room number
          if (class_.roomNumber != null)
            Row(
              children: [
                const Icon(Icons.meeting_room, size: 14, color: Color(0xFF06B6D4)),
                const SizedBox(width: 4),
                Text(
                  'Room ${class_.roomNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          const Spacer(),
          // View button
          TextButton(
            onPressed: () {
              // Navigate to class details
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }
}
