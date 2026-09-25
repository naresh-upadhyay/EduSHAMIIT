import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class StaffTab extends ConsumerStatefulWidget {
  const StaffTab({super.key});

  @override
  ConsumerState<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends ConsumerState<StaffTab> {
  final _searchController = TextEditingController();
  List<dynamic> _teachers = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _selectedRoleFilter = 'all';

  Future<void> _fetchTeachers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final search = _searchController.text.trim();
      final queryParams = <String>[];
      if (search.isNotEmpty) queryParams.add('search=$search');
      if (_selectedRoleFilter != 'all') {
        queryParams.add('role=$_selectedRoleFilter');
      } else {
        queryParams.add('role=all');
      }
      final queryStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final path = '/admin/teachers/list$queryStr';

      final response = await ApiService().get(path);

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          _teachers = data['teachers'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['detail'] ?? 'Failed to load staff';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _showAssignClassesDialog(Map<String, dynamic> teacher) async {
    final String teacherId = teacher['id'];
    final String teacherName = teacher['full_name'];
    final String teacherEmail = teacher['email'];

    final classes = ['10A', '10B', '11A', '11B', '12A', '12B'];
    final selectedClasses = <String>{};
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Assign Classes to Teacher',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$teacherName ($teacherEmail)',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Classes:',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: classes.map((cls) {
                        final isSelected = selectedClasses.contains(cls);
                        return FilterChip(
                          label: Text(cls),
                          selected: isSelected,
                          selectedColor: const Color(0xFF4F46E5),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          backgroundColor: isDark ? const Color(0xFF0F1222) : const Color(0xFFF1F5F9),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedClasses.add(cls);
                              } else {
                                selectedClasses.remove(cls);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting || selectedClasses.isEmpty
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          try {
                            final res = await ApiService().post(
                              '/admin/teachers/$teacherId/assign-classes',
                              {'classes': selectedClasses.toList()},
                            );
                            if (res['success'] == true) {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Classes successfully assigned to teacher!')),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['detail'] ?? 'Failed to assign classes'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    disabledBackgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Assign', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Staff Directory & Assignments',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'List teachers, view profile details, and assign class schedules dynamically.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),

          // Search Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: isDark
                          ? BorderSide.none
                          : const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  onSubmitted: (_) => _fetchTeachers(),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _fetchTeachers,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleFilterChip('all', 'All Staff'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('teacher', 'Teachers'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('support', 'Support Staff'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('driver', 'Transport & Drivers'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('finance', 'Finance & Accounts'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('admin', 'Administrators'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _teachers.isEmpty
                        ? const Center(
                            child: Text(
                            'No staff members found matching criteria',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ))
                        : ListView.builder(
                            itemCount: _teachers.length,
                            itemBuilder: (context, index) {
                              final teacher = _teachers[index] as Map<String, dynamic>;
                              final roleStr = (teacher['role'] ?? 'teacher').toString();
                              final isTeacher = roleStr == 'teacher';
                              final deptStr = teacher['department'] ?? teacher['specialization'] ?? (isTeacher ? 'Academics' : 'Administration');
                              final desigStr = teacher['designation'] ?? (isTeacher ? 'Teacher' : roleStr.toUpperCase());

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundImage: teacher['avatar_url'] != null &&
                                                    (teacher['avatar_url'].toString().startsWith('http://') ||
                                                     teacher['avatar_url'].toString().startsWith('https://'))
                                                ? NetworkImage(teacher['avatar_url'])
                                                : null,
                                            backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                            child: teacher['avatar_url'] == null ||
                                                    (!teacher['avatar_url'].toString().startsWith('http://') &&
                                                     !teacher['avatar_url'].toString().startsWith('https://'))
                                                ? Icon(isTeacher ? Icons.person : (roleStr == 'driver' ? Icons.directions_bus : Icons.badge_outlined), color: const Color(0xFF4F46E5))
                                                : null,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        teacher['full_name'] ?? 'No Name',
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                          fontFamily: 'Outfit',
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (teacher['employee_id'] != null) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          teacher['employee_id'],
                                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isTeacher ? const Color(0xFFEEF2FF) : const Color(0xFFFEF3C7),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        roleStr.toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: isTeacher ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${teacher['email'] ?? 'No email'}  •  $desigStr  •  $deptStr',
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 11,
                                                    fontFamily: 'Outfit',
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (isTeacher)
                                      ElevatedButton.icon(
                                        onPressed: () => _showAssignClassesDialog(teacher),
                                        icon: const Icon(Icons.add_task_rounded, size: 16),
                                        label: const Text('Assign Classes', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4F46E5),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          desigStr,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String role, String label) {
    final isSelected = _selectedRoleFilter == role;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _selectedRoleFilter = role;
        });
        _fetchTeachers();
      },
      selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
      checkmarkColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }
}
