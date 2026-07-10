import 'package:flutter/material.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final List<Map<String, dynamic>> _users = [
    {
      'name': 'Naresh Upadhyay',
      'email': 'naresh@shamiit.com',
      'role': 'Super Admin',
      'school': 'System-wide',
      'status': 'Active',
    },
    {
      'name': 'Rahul Kapoor',
      'email': 'rahul@shamiit.com',
      'role': 'Super Admin',
      'school': 'System-wide',
      'status': 'Active',
    },
    {
      'name': 'Rakesh Sharma',
      'email': 'r.sharma@noida.eduverse.com',
      'role': 'School Admin',
      'school': 'Noida International School',
      'status': 'Active',
    },
    {
      'name': 'Ananya Verma',
      'email': 'a.verma@noida.eduverse.com',
      'role': 'Teacher',
      'school': 'Noida International School',
      'status': 'Active',
    },
    {
      'name': 'Arjun Kumar',
      'email': 'arjun.kumar@student.com',
      'role': 'Student',
      'school': 'Noida International School',
      'status': 'Active',
    },
    {
      'name': 'Priya Gupta',
      'email': 'p.gupta@dps.eduverse.com',
      'role': 'Teacher',
      'school': 'Delhi Public School',
      'status': 'Inactive',
    },
    {
      'name': 'Vikram Singh',
      'email': 'v.singh@dps.eduverse.com',
      'role': 'School Admin',
      'school': 'Delhi Public School',
      'status': 'Active',
    },
  ];

  String _selectedRoleFilter = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredUsers = _users.where((user) {
      final matchesRole = _selectedRoleFilter == 'All' || user['role'] == _selectedRoleFilter;
      final matchesSearch = user['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user['email'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user['school'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesRole && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'User Management Directory',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search Bar
            TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name, email, or school...',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: isDark
                      ? BorderSide.none
                      : const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Tabs/Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Super Admin', 'School Admin', 'Teacher', 'Student'].map((role) {
                  final isSelected = _selectedRoleFilter == role;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(role),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedRoleFilter = role;
                          });
                        }
                      },
                      backgroundColor: theme.cardColor,
                      selectedColor: const Color(0xFF4F46E5),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: isSelected
                            ? BorderSide.none
                            : BorderSide(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Users list
            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  final isActive = user['status'] == 'Active';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
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
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          child: Text(
                            user['name'][0],
                            style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user['name'],
                                    style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Outfit'),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      user['role'],
                                      style: const TextStyle(
                                          color: Color(0xFF818CF8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Outfit'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user['email'],
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user['school'],
                                style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 16),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Impersonating ${user['name']}')),
                                    );
                                  },
                                  tooltip: 'Impersonate Support',
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 16),
                                  onPressed: () {},
                                  tooltip: 'Edit Details',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
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
