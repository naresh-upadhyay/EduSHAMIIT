import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_admin/screens/tabs/command_center_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/finance_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/defaulters_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/staff_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/admissions_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/gate_scanner_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/support_tab.dart';
import 'package:edu_shamiit_admin/screens/tabs/system_control_tab.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const CommandCenterTab(),
    const FinanceTab(),
    const DefaultersTab(),
    const StaffTab(),
    const AdmissionsTab(),
    const GateScannerTab(),
    const SupportTab(),
    const SystemControlTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final userName = user?['full_name'] ?? 'System Administrator';

    return Scaffold(
      backgroundColor: const Color(0xFF090B15),
      body: Row(
        children: [
          // Sidebar Navigation (Desktop First)
          Container(
            width: 260,
            color: const Color(0xFF0B0D19),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header
                Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFF4F46E5),
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'EduVerse Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Navigation Items
                Expanded(
                  child: ListView(
                    children: [
                      _buildSidebarItem(0, 'Command Center', Icons.dashboard_outlined),
                      _buildSidebarItem(1, 'Financial Suite', Icons.payments_outlined),
                      _buildSidebarItem(2, 'Fee Defaulters', Icons.warning_amber_rounded),
                      _buildSidebarItem(3, 'Staff & Class Registry', Icons.people_outline_rounded),
                      _buildSidebarItem(4, 'New Admissions', Icons.person_add_alt_1_outlined),
                      _buildSidebarItem(5, 'Gate Scanner Log', Icons.qr_code_scanner_rounded),
                      _buildSidebarItem(6, 'IT Support Tickets', Icons.support_agent_rounded),
                      _buildSidebarItem(7, 'Security & Controls', Icons.security_rounded),
                    ],
                  ),
                ),

                // User profile & logout
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                      child: const Icon(Icons.person, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Super Admin',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
                      onPressed: () {
                        ref.read(authProvider.notifier).signOut();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Content Panel
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar
                Container(
                  height: 70,
                  color: const Color(0xFF0B0D19),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Search bar
                      SizedBox(
                        width: 300,
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search control index...',
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF13182C),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      // Notification trigger
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No new system alerts.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Selected Tab Content
                Expanded(
                  child: _tabs[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAiAssistantDialog(context),
        backgroundColor: const Color(0xFF4F46E5),
        child: const Icon(Icons.assistant, color: Colors.white),
      ),
    );
  }

  Widget _buildSidebarItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        selected: isSelected,
        selectedTileColor: const Color(0xFF4F46E5).withOpacity(0.15),
      ),
    );
  }

  void _showAiAssistantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF13182C),
          title: Row(
            children: const [
              Icon(Icons.assistant, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text('Shami — AI Admin Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How can I help you customize or control school operations today?',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g., Send notice to 10A, check collections...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF0B0D19),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                final prompt = textController.text.trim();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('AI processing request: "$prompt"')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              child: const Text('Execute Prompt', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
