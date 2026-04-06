import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherMaterials extends StatefulWidget {
  const TeacherMaterials({super.key});

  @override
  State<TeacherMaterials> createState() => _TeacherMaterialsState();
}

class _TeacherMaterialsState extends State<TeacherMaterials> {
  String _selectedClass = 'All';
  final List<String> _classes = ['All', 'X-A', 'X-B', 'X-C', 'IX-A', 'IX-B'];

  String _selectedTab = 'All';
  final List<String> _tabs = ['All', 'PDF', 'PPT', 'Video', 'Document'];

  final List<Map<String, dynamic>> _materials = [
    {
      'id': '1',
      'title': 'Trigonometry Formulas Sheet',
      'type': 'PDF',
      'class': 'X-A',
      'subject': 'Mathematics',
      'size': '2.5 MB',
      'uploadedAt': DateTime.now().subtract(const Duration(days: 2)),
      'downloads': 42,
      'icon': Icons.picture_as_pdf,
      'color': const Color(0xFFEF4444),
    },
    {
      'id': '2',
      'title': 'Quadratic Equations Lecture',
      'type': 'PPT',
      'class': 'X-B',
      'subject': 'Mathematics',
      'size': '8.3 MB',
      'uploadedAt': DateTime.now().subtract(const Duration(days: 5)),
      'downloads': 38,
      'icon': Icons.slideshow,
      'color': const Color(0xFF0EA5E9),
    },
    {
      'id': '3',
      'title': 'Laws of Motion - Video',
      'type': 'Video',
      'class': 'IX-A',
      'subject': 'Physics',
      'size': '45.2 MB',
      'uploadedAt': DateTime.now().subtract(const Duration(days: 1)),
      'downloads': 35,
      'icon': Icons.video_library,
      'color': const Color(0xFF059669),
    },
    {
      'id': '4',
      'title': 'Lesson Plan - Chapter 8',
      'type': 'Document',
      'class': 'X-A',
      'subject': 'Mathematics',
      'size': '1.2 MB',
      'uploadedAt': DateTime.now().subtract(const Duration(days: 7)),
      'downloads': 15,
      'icon': Icons.description,
      'color': const Color(0xFF6366F1),
    },
    {
      'id': '5',
      'title': 'Statistics Notes',
      'type': 'PDF',
      'class': 'X-C',
      'subject': 'Mathematics',
      'size': '3.8 MB',
      'uploadedAt': DateTime.now().subtract(const Duration(days: 10)),
      'downloads': 40,
      'icon': Icons.picture_as_pdf,
      'color': const Color(0xFFEF4444),
    },
  ];

  List<Map<String, dynamic>> get _filteredMaterials {
    var filtered = _materials;
    if (_selectedTab != 'All') {
      filtered = filtered.where((m) => m['type'] == _selectedTab).toList();
    }
    if (_selectedClass != 'All') {
      filtered = filtered.where((m) => m['class'] == _selectedClass).toList();
    }
    return filtered;
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
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
                  'Teaching Materials',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.upload, color: Colors.white),
                  onPressed: () => _showUploadDialog(),
                ),
              ],
            ),
          ),

          // Class filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Class:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _classes.map((cls) {
                        final isSelected = _selectedClass == cls;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedClass = cls),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cls,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Type tabs
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

          // Materials list
          Expanded(
            child: _filteredMaterials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📁', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No materials found',
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
                    itemCount: _filteredMaterials.length,
                    itemBuilder: (context, index) {
                      return _buildMaterialCard(_filteredMaterials[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadDialog(),
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.upload, color: Colors.white),
        label: const Text(
          'Upload Material',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material) {
    final icon = material['icon'] as IconData;
    final color = material['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material['title'] as String,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        material['type'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${material['class']} • ${material['subject']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      material['size'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${_formatDate(material['uploadedAt'] as DateTime)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${material['downloads']} downloads',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFF0EA5E9)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('📥 Downloading...')),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Material'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withOpacity(0.3),
                      strokeAlign: BorderSide.strokeAlignCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_upload, size: 48, color: const Color(0xFF0EA5E9)),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select file',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF0EA5E9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'PDF, PPT, Video, Document',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter material title',
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
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {},
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
                const SnackBar(content: Text('✅ Material uploaded successfully!')),
              );
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}