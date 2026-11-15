import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';

class HostelMessMenuDialog extends ConsumerStatefulWidget {
  const HostelMessMenuDialog({super.key});

  @override
  ConsumerState<HostelMessMenuDialog> createState() => _HostelMessMenuDialogState();
}

class _HostelMessMenuDialogState extends ConsumerState<HostelMessMenuDialog> {
  int _activeTab = 0; // 0: Weekly Menu, 1: Dietary Profiles, 2: Mess Rebates
  String _selectedDay = 'MONDAY';
  List<Map<String, dynamic>> _menus = [];
  List<Map<String, dynamic>> _dietaryProfiles = [];
  List<Map<String, dynamic>> _rebates = [];
  bool _isLoading = true;

  final List<String> _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final service = ref.read(hostelProvider.notifier).service;
    try {
      final menus = await service.getMessMenus(dayOfWeek: _selectedDay);
      final profiles = await service.getDietaryProfiles();
      final rebates = await service.getMessRebates();
      if (mounted) {
        setState(() {
          _menus = menus;
          _dietaryProfiles = profiles;
          _rebates = rebates;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 860,
        height: 680,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Color(0xFFF97316), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hostel Mess & Dining Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Weekly meal schedules, student dietary profiles & leave mess rebate tracking',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Switcher (Weekly Menu | Dietary Profiles | Leave Rebates)
            Row(
              children: [
                _buildTabButton(0, 'Weekly Menu', Icons.menu_book_rounded, isDark),
                const SizedBox(width: 8),
                _buildTabButton(1, 'Dietary Profiles (${_dietaryProfiles.length})', Icons.eco_rounded, isDark),
                const SizedBox(width: 8),
                _buildTabButton(2, 'Leave Rebates (${_rebates.length})', Icons.receipt_long_rounded, isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Body Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                  : _activeTab == 0
                      ? _buildMenuTab(isDark)
                      : _activeTab == 1
                          ? _buildDietaryTab(isDark)
                          : _buildRebatesTab(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon, bool isDark) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF97316)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Day Selector Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _days.map((day) {
              final isDaySelected = _selectedDay == day;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(day[0] + day.substring(1).toLowerCase()),
                  selected: isDaySelected,
                  onSelected: (val) {
                    setState(() => _selectedDay = day);
                    _loadData();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Meal Cards
        Expanded(
          child: _menus.isEmpty
              ? const Center(child: Text('No menu items configured for this day'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.45,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _menus.length,
                  itemBuilder: (context, idx) {
                    final m = _menus[idx];
                    final mealType = m['meal_type']?.toString() ?? 'MEAL';
                    final items = (m['items'] as List?)?.map((e) => e.toString()).toList() ?? [];
                    final start = m['timing_start']?.toString().substring(0, 5) ?? '07:30';
                    final end = m['timing_end']?.toString().substring(0, 5) ?? '09:00';
                    final calories = m['calories_estimate'] ?? 500;

                    Color cardColor = const Color(0xFFF59E0B);
                    if (mealType == 'LUNCH') cardColor = const Color(0xFF10B981);
                    if (mealType == 'SNACKS') cardColor = const Color(0xFF6366F1);
                    if (mealType == 'DINNER') cardColor = const Color(0xFF8B5CF6);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardColor.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cardColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mealType,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cardColor),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$start - $end',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '~$calories kcal',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (ctx, i) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          items[i],
                                          style: const TextStyle(fontSize: 12),
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
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDietaryTab(bool isDark) {
    if (_dietaryProfiles.isEmpty) {
      return const Center(child: Text('No dietary profiles recorded'));
    }
    return ListView.separated(
      itemCount: _dietaryProfiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final p = _dietaryProfiles[i];
        final diet = p['diet_type']?.toString() ?? 'VEGETARIAN';
        final allergies = p['allergies']?.toString() ?? 'None';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
            child: const Icon(Icons.person_rounded, color: Color(0xFF10B981)),
          ),
          title: Text(p['student_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Hostel: ${p['building_name'] ?? '-'} | Room: ${p['room_number'] ?? '-'} | Allergies: $allergies'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: diet == 'VEGETARIAN' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              diet,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: diet == 'VEGETARIAN' ? const Color(0xFF15803D) : const Color(0xFFB45309),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRebatesTab(bool isDark) {
    if (_rebates.isEmpty) {
      return const Center(child: Text('No mess rebates processed yet for student leaves'));
    }
    return ListView.separated(
      itemCount: _rebates.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final r = _rebates[i];
        return ListTile(
          leading: const Icon(Icons.credit_card_rounded, color: Color(0xFF2563EB)),
          title: Text('${r['student_name']} (${r['leave_number'] ?? 'Leave'})'),
          subtitle: Text('${r['start_date']} to ${r['end_date']} • ${r['total_days']} Days @ ₹${r['rebate_rate_per_day']}/day'),
          trailing: Text(
            '₹${r['total_rebate_amount']}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
          ),
        );
      },
    );
  }
}
