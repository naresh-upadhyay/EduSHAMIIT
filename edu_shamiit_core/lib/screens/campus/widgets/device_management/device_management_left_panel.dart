import 'package:flutter/material.dart';

class DeviceManagementLeftPanel extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onAddDevice;

  static const List<SubNavItem> navItems = [
    SubNavItem(title: 'Control Dashboard', icon: Icons.tune_rounded),
    SubNavItem(title: 'Device Registry', icon: Icons.inventory_2_outlined),
    SubNavItem(title: 'Device Types & Profiles', icon: Icons.memory_rounded),
    SubNavItem(title: 'Device Groups', icon: Icons.grid_view_rounded),
    SubNavItem(title: 'Locations & Mapping', icon: Icons.place_outlined),
    SubNavItem(title: 'Live Control', icon: Icons.sensors_rounded),
    SubNavItem(title: 'Bulk Operations', icon: Icons.playlist_play_rounded),
    SubNavItem(title: 'Automation Rules', icon: Icons.auto_mode_rounded),
    SubNavItem(title: 'Schedules', icon: Icons.schedule_rounded),
    SubNavItem(title: 'Scenes & Presets', icon: Icons.auto_awesome_rounded),
    SubNavItem(title: 'Energy & Usage', icon: Icons.bolt_rounded),
    SubNavItem(title: 'Device Health & Diagnostics', icon: Icons.health_and_safety_outlined),
    SubNavItem(title: 'Integrations & Gateways', icon: Icons.hub_outlined),
    SubNavItem(title: 'Access & Permissions', icon: Icons.lock_outline_rounded),
    SubNavItem(title: 'Audit Logs', icon: Icons.history_rounded),
    SubNavItem(title: 'Import / Export', icon: Icons.import_export_rounded),
  ];

  const DeviceManagementLeftPanel({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onAddDevice,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "+ Add New Device" Primary Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: onAddDevice,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'Add New Device',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 16 Nav Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Tooltip(
                    message: item.title,
                    waitDuration: const Duration(milliseconds: 600),
                    child: InkWell(
                      onTap: () => onItemSelected(index),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: -0.2,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SubNavItem {
  final String title;
  final IconData icon;

  const SubNavItem({
    required this.title,
    required this.icon,
  });
}
