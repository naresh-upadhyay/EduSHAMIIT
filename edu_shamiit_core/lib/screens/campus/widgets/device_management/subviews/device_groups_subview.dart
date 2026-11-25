import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device_management_models.dart';
import '../../../providers/device_management_provider.dart';
import '../dialogs/create_edit_device_group_dialog.dart';
import '../dialogs/advanced_group_control_dialog.dart';
import '../dialogs/group_members_management_dialog.dart';
import '../../common/campus_pagination_bar.dart';

class DeviceGroupsSubview extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>>? groups;
  final List<DeviceItemModel>? availableDevices;
  final VoidCallback? onBackToDashboard;
  final Function(String groupId, String action)? onGroupAction;
  final Function(Map<String, dynamic> data)? onCreateGroup;
  final Function(String groupId, Map<String, dynamic> data)? onUpdateGroup;
  final Function(String groupId)? onDeleteGroup;

  const DeviceGroupsSubview({
    super.key,
    this.groups,
    this.availableDevices,
    this.onBackToDashboard,
    this.onGroupAction,
    this.onCreateGroup,
    this.onUpdateGroup,
    this.onDeleteGroup,
  });

  @override
  ConsumerState<DeviceGroupsSubview> createState() => _DeviceGroupsSubviewState();
}

class _DeviceGroupsSubviewState extends ConsumerState<DeviceGroupsSubview> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedGroupIds = {};

  // Expandable accordion states in right panel
  bool _isSchedulesExpanded = false;
  bool _isAutomationsExpanded = false;
  bool _isScenesExpanded = false;
  bool _isEnergyExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceManagementProvider.notifier).loadDeviceGroupsData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================================
  // DIALOGS & HANDLERS
  // ============================================================================

  void _openCreateDialog() {
    final state = ref.read(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);

    showDialog(
      context: context,
      builder: (_) => CreateEditDeviceGroupDialog(
        availableDevices: state.devices,
        onSave: (data) async {
          final ok = await notifier.createGroupItem(data);
          if (mounted && ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device Group "${data['name']}" created successfully!')),
            );
          }
        },
      ),
    );
  }

  void _openEditDialog(DeviceGroupItem group) {
    final state = ref.read(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);

    showDialog(
      context: context,
      builder: (_) => CreateEditDeviceGroupDialog(
        initialGroupItem: group,
        availableDevices: state.devices,
        onSave: (data) async {
          final ok = await notifier.updateGroupItem(group.id, data);
          if (mounted && ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device Group "${data['name']}" updated successfully!')),
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteGroup(DeviceGroupItem group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${group.name}?'),
        content: const Text(
          'Are you sure you want to delete this device group? Member devices will not be affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(deviceManagementProvider.notifier);
      await notifier.deleteGroupItem(group.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "${group.name}" deleted.')),
        );
      }
    }
  }

  void _openAdvancedControlDialog(DeviceGroupItem group) {
    showDialog(
      context: context,
      builder: (_) => AdvancedGroupControlDialog(
        group: group,
        onExecuteCommand: (command, payload) async {
          final notifier = ref.read(deviceManagementProvider.notifier);
          final res = await notifier.executeGroupControlCommand(group.id, command, payload);
          if (mounted) {
            final sent = res['sent_commands'] ?? 0;
            final failed = res['failed_devices'] ?? 0;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Command dispatched: $sent sent, $failed failed via MQTT.'),
                backgroundColor: failed == 0 ? Colors.green.shade700 : Colors.orange.shade800,
              ),
            );
          }
        },
      ),
    );
  }

  void _openMembersDialog(DeviceGroupItem group) {
    final state = ref.read(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);
    showDialog(
      context: context,
      builder: (_) => GroupMembersManagementDialog(
        group: group,
        members: state.selectedGroupMembers,
        allAvailableDevices: state.devices,
        onAddMembers: (deviceIds) async {
          await notifier.addGroupMembers(group.id, deviceIds);
        },
        onRemoveMember: (deviceId) async {
          await notifier.removeGroupMember(group.id, deviceId);
        },
      ),
    );
  }

  void _showQuickBrightnessDialog(DeviceGroupItem group) {
    double currentBrightness = 80.0;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 8),
                  Text('Set Brightness - ${group.name}', style: const TextStyle(fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${currentBrightness.toInt()}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Slider(
                    value: currentBrightness,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: const Color(0xFF2563EB),
                    label: '${currentBrightness.toInt()}%',
                    onChanged: (val) => setDialogState(() => currentBrightness = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(ctx).pop();
                    final notifier = ref.read(deviceManagementProvider.notifier);
                    await notifier.executeGroupControlCommand(group.id, 'set_brightness', {
                      'brightness': currentBrightness.toInt(),
                    });
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Brightness set to ${currentBrightness.toInt()}% for all members.')),
                      );
                    }
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _exportGroups() async {
    final notifier = ref.read(deviceManagementProvider.notifier);
    final count = await notifier.exportDeviceGroupsCsv();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully exported $count groups.')),
      );
    }
  }

  void _importGroups() async {
    final notifier = ref.read(deviceManagementProvider.notifier);
    final count = await notifier.importDeviceGroups();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully processed import: $count groups synced.')),
      );
    }
  }

  // ============================================================================
  // BUILD ROOT
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1150;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top KPI Summary Bar (128 Groups, 118 Active (92.2%), 8,742 Total Devices, 8,296 Grouped (95.0%), 446 Ungrouped (5.0%))
              _buildKpisBar(state.groupsKpis, isDark),
              const SizedBox(height: 16),

              // 2. Section Header & Action Buttons (+ Create Group, Import, Export)
              _buildSectionHeader(context, notifier, state, isDark),
              const SizedBox(height: 14),

              // 3. Sub-Tabs Bar (All Groups (128), Active (118), Inactive (10))
              _buildSubTabsBar(state.groupsActiveSubTab, state.groupsKpis, notifier),
              const SizedBox(height: 14),

              // 4. Filters & Search Row (Search input, Location, Device Types, Profiles, Grid/Table view)
              _buildFiltersRow(state, notifier, isDark),
              const SizedBox(height: 14),

              // 5. Main Content Area (Table or Grid + Right Inspector Panel)
              _buildMainArea(state, notifier, isDark, isWide),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // 1. TOP KPI BAR
  // ============================================================================

  Widget _buildKpisBar(DeviceGroupsKpis kpis, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1050;

        final cards = [
          _buildKpiCard(
            title: 'Total Groups',
            value: '${kpis.totalGroups}',
            subtext: null,
            icon: Icons.hub_rounded,
            iconBg: const Color(0xFF2563EB).withValues(alpha: 0.12),
            iconColor: const Color(0xFF2563EB),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Active Groups',
            value: '${kpis.activeGroups}',
            subtext: '(${kpis.activeGroupsPct.toStringAsFixed(1)}%)',
            subtextColor: const Color(0xFF059669),
            icon: Icons.power_settings_new_rounded,
            iconBg: const Color(0xFF059669).withValues(alpha: 0.12),
            iconColor: const Color(0xFF059669),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Total Devices',
            value: _formatNumber(kpis.totalDevices),
            subtext: null,
            icon: Icons.layers_rounded,
            iconBg: const Color(0xFF0284C7).withValues(alpha: 0.12),
            iconColor: const Color(0xFF0284C7),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Grouped Devices',
            value: _formatNumber(kpis.groupedDevices),
            subtext: '(${kpis.groupedDevicesPct.toStringAsFixed(1)}%)',
            subtextColor: const Color(0xFF059669),
            icon: Icons.devices_other_rounded,
            iconBg: const Color(0xFF0D9488).withValues(alpha: 0.12),
            iconColor: const Color(0xFF0D9488),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Ungrouped Devices',
            value: '${kpis.ungroupedDevices}',
            subtext: '(${kpis.ungroupedDevicesPct.toStringAsFixed(1)}%)',
            subtextColor: const Color(0xFF7C3AED),
            icon: Icons.link_off_rounded,
            iconBg: const Color(0xFF7C3AED).withValues(alpha: 0.12),
            iconColor: const Color(0xFF7C3AED),
            isDark: isDark,
          ),
        ];

        if (isMobile) {
          return Column(
            children: cards
                .map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c))
                .toList(),
          );
        } else if (isTablet) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 20) / 2, child: c)).toList(),
          );
        }

        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    String? subtext,
    Color? subtextColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtext != null)
                      Text(
                        subtext,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: subtextColor ?? const Color(0xFF059669),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. SECTION HEADER & ACTION BUTTONS
  // ============================================================================

  Widget _buildSectionHeader(BuildContext context, DeviceManagementNotifier notifier, DeviceManagementState state, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        final titleCol = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Groups',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Organize devices into logical groups for easier control, automation and scheduling.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final buttonsRow = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _importGroups,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Import', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _exportGroups,
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text('Export', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleCol,
              const SizedBox(height: 12),
              buttonsRow,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleCol),
            buttonsRow,
          ],
        );
      },
    );
  }

  // ============================================================================
  // 3. SUB-TABS BAR
  // ============================================================================

  Widget _buildSubTabsBar(String activeSubTab, DeviceGroupsKpis kpis, DeviceManagementNotifier notifier) {
    final tabs = [
      'All Groups (${kpis.totalGroups})',
      'Active (${kpis.activeGroups})',
      'Inactive (${kpis.totalGroups - kpis.activeGroups})',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = activeSubTab.startsWith(tab.split(' ')[0]);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => notifier.setGroupsSubTab(tab),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================================
  // 4. FILTERS & SEARCH ROW
  // ============================================================================

  Widget _buildFiltersRow(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        // Dynamic Options loaded from database
        final locationOptions = [
          'All Locations',
          ...state.groupsDynamicLocations.where((l) => l.trim().isNotEmpty && l != 'All Locations'),
        ];
        final typeOptions = [
          'All Device Types',
          ...state.groupsDynamicTypes.where((t) => t.trim().isNotEmpty && t != 'All Device Types'),
        ];
        final profileOptions = [
          'All Profiles',
          ...state.groupsDynamicProfiles.where((p) => p.trim().isNotEmpty && p != 'All Profiles'),
        ];

        final searchField = SizedBox(
          width: isMobile ? double.infinity : 320,
          child: TextField(
            controller: _searchController,
            onChanged: notifier.setGroupsSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search groups by name, building, device type...',
              hintStyle: const TextStyle(fontSize: 12.5),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        notifier.setGroupsSearchQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
          ),
        );

        final dropdowns = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Location dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: AppSearchableDropdown<String>.fromMenuItems(
                  value: locationOptions.contains(state.groupsFilterLocation) ? state.groupsFilterLocation : locationOptions.first,
                  isDense: true,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                  items: locationOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setGroupsFilterLocation(val);
                  },
                ),
              ),
            ),

            // Device Type dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: AppSearchableDropdown<String>.fromMenuItems(
                  value: typeOptions.contains(state.groupsFilterType) ? state.groupsFilterType : typeOptions.first,
                  isDense: true,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                  items: typeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setGroupsFilterType(val);
                  },
                ),
              ),
            ),

            // Profile dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: AppSearchableDropdown<String>.fromMenuItems(
                  value: profileOptions.contains(state.groupsFilterProfile) ? state.groupsFilterProfile : profileOptions.first,
                  isDense: true,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                  items: profileOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setGroupsFilterProfile(val);
                  },
                ),
              ),
            ),
          ],
        );

        final viewToggle = Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                color: state.groupsIsGridView ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                onPressed: () => notifier.setGroupsViewMode(true),
                tooltip: 'Grid View',
              ),
              IconButton(
                icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                color: !state.groupsIsGridView ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                onPressed: () => notifier.setGroupsViewMode(false),
                tooltip: 'Table View',
              ),
            ],
          ),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    dropdowns,
                    const SizedBox(width: 8),
                    viewToggle,
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            searchField,
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: dropdowns,
              ),
            ),
            const SizedBox(width: 12),
            viewToggle,
          ],
        );
      },
    );
  }

  // ============================================================================
  // 5. MAIN CONTENT AREA (DATA TABLE / GRID + RIGHT INSPECTOR PANEL)
  // ============================================================================

  Widget _buildMainArea(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark, bool isWide) {
    if (state.isGroupsLoading && state.groupsList.isEmpty) {
      return Container(
        height: 380,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading campus device groups...'),
          ],
        ),
      );
    }

    final tableWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.groupsIsGridView)
          _buildGridView(state, notifier, isDark)
        else
          _buildTableView(state, notifier, isDark),
        const SizedBox(height: 12),
        _buildPaginationBar(state, notifier, isDark),
      ],
    );

    // If wide screen, display Table on Left and Inspector Panel on Right
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: tableWidget),
          const SizedBox(width: 16),
          SizedBox(
            width: 360,
            child: _buildRightInspectorPanel(state, notifier, isDark),
          ),
        ],
      );
    }

    // Medium or narrow screens: stack vertically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tableWidget,
        const SizedBox(height: 18),
        _buildRightInspectorPanel(state, notifier, isDark),
      ],
    );
  }

  // ============================================================================
  // TABLE VIEW
  // ============================================================================

  Widget _buildTableView(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final groups = state.groupsList;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bulk Actions Bar for Groups
            if (_selectedGroupIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.08),
                  border: Border(bottom: BorderSide(color: primaryColor.withValues(alpha: 0.2))),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedGroupIds.length} of ${groups.length} groups selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(width: 20),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check, size: 14, color: Color(0xFF16A34A)),
                        label: const Text('Activate', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                        ),
                        onPressed: () async {
                          await notifier.bulkUpdateDeviceGroupsStatus(_selectedGroupIds.toList(), 'active');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Activated ${_selectedGroupIds.length} group(s)')),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.block, size: 14, color: Color(0xFFD97706)),
                        label: const Text('Deactivate', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: Color(0xFFFCD34D)),
                        ),
                        onPressed: () async {
                          await notifier.bulkUpdateDeviceGroupsStatus(_selectedGroupIds.toList(), 'inactive');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deactivated ${_selectedGroupIds.length} group(s)')),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                        label: const Text('Delete', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                        ),
                        onPressed: () async {
                          final count = _selectedGroupIds.length;
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Selected Device Groups?'),
                              content: Text('Are you sure you want to delete $count selected group(s)?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await notifier.bulkDeleteDeviceGroups(_selectedGroupIds.toList());
                            setState(() => _selectedGroupIds.clear());
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$count group(s) deleted successfully')),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _selectedGroupIds.clear()),
                        child: Text('Deselect All', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ),
                    ],
                  ),
                ),
              ),

            if (state.isGroupsLoading)
              Container(
                height: 240,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              )
            else if (groups.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_outlined, size: 54, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    const SizedBox(height: 14),
                    Text(
                      'No device groups found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try adjusting your search or filters, or create a new group.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _openCreateDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 860),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowHeight: 44,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 56,
                    horizontalMargin: 12,
                    columnSpacing: 16,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    ),
                    columns: [
                      DataColumn(
                        label: Checkbox(
                          value: groups.isNotEmpty && _selectedGroupIds.length == groups.length,
                          activeColor: primaryColor,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedGroupIds.addAll(groups.map((g) => g.id));
                              } else {
                                _selectedGroupIds.clear();
                              }
                            });
                          },
                        ),
                      ),
                      DataColumn(
                        label: _buildSortHeader('Group Name', 'name', state, primaryColor),
                      ),
                      DataColumn(
                        label: _buildSortHeader('Group Type', 'group_type', state, primaryColor),
                      ),
                      DataColumn(
                        label: _buildSortHeader('Location / Scope', 'location_scope', state, primaryColor),
                      ),
                      DataColumn(
                        label: _buildSortHeader('Devices', 'devices', state, primaryColor),
                      ),
                      DataColumn(
                        label: _buildSortHeader('Profile', 'profile_name', state, primaryColor),
                      ),
                      DataColumn(
                        label: _buildSortHeader('Status', 'status', state, primaryColor),
                      ),
                      const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                    ],
                  rows: groups.map((g) {
                    final isSelected = state.selectedGroupId == g.id;
                    final isChecked = _selectedGroupIds.contains(g.id);
                    final typeColor = _getGroupTypeColor(g.groupType);

                    return DataRow(
                      selected: isSelected,
                      color: WidgetStateProperty.resolveWith((states) {
                        if (isSelected) {
                          return primaryColor.withValues(alpha: isDark ? 0.25 : 0.08);
                        }
                        return null;
                      }),
                      onSelectChanged: (_) => notifier.selectDeviceGroup(g.id),
                  cells: [
                    // Checkbox
                    DataCell(
                      Checkbox(
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedGroupIds.add(g.id);
                            } else {
                              _selectedGroupIds.remove(g.id);
                            }
                          });
                        },
                      ),
                    ),
                    // Group Name + Icon + Subtext
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(_getGroupTypeIcon(g.groupType), color: typeColor, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                g.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                g.description.isNotEmpty ? g.description : g.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Group Type badge
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: typeColor.withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 12, color: typeColor),
                            const SizedBox(width: 3),
                            Text(
                              g.groupType,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Location / Scope
                    DataCell(
                      Text(
                        g.locationScope.isNotEmpty ? g.locationScope : 'All Buildings',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    // Devices count
                    DataCell(
                      Text(
                        '${g.memberCount}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ),
                    // Profile
                    DataCell(
                      Text(
                        g.profileName.isNotEmpty ? g.profileName : 'Default',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    // Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: g.status.toLowerCase() == 'active'
                              ? const Color(0xFF059669).withValues(alpha: 0.12)
                              : const Color(0xFF64748B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: g.status.toLowerCase() == 'active'
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              g.status.toLowerCase() == 'active' ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: g.status.toLowerCase() == 'active'
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Actions (Play, Edit, More)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Quick Play button
                          IconButton(
                            icon: const Icon(Icons.play_arrow_outlined, size: 18, color: Color(0xFF2563EB)),
                            onPressed: () => _openAdvancedControlDialog(g),
                            tooltip: 'Group Commands',
                          ),
                          // Edit button
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                            onPressed: () => _openEditDialog(g),
                            tooltip: 'Edit Group',
                          ),
                          // More menu
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                            tooltip: 'More Options',
                            onSelected: (val) async {
                              switch (val) {
                                case 'advanced':
                                  _openAdvancedControlDialog(g);
                                  break;
                                case 'members':
                                  _openMembersDialog(g);
                                  break;
                                case 'brightness':
                                  _showQuickBrightnessDialog(g);
                                  break;
                                case 'duplicate':
                                  await notifier.duplicateGroupItem(g.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Duplicated "${g.name}"')),
                                    );
                                  }
                                  break;
                                case 'toggle_status':
                                  final newStatus = g.status.toLowerCase() == 'active' ? 'inactive' : 'active';
                                  await notifier.toggleGroupStatusItem(g.id, newStatus);
                                  break;
                                case 'delete':
                                  _confirmDeleteGroup(g);
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'advanced', child: Text('Advanced Control')),
                              const PopupMenuItem(value: 'members', child: Text('Manage Members')),
                              const PopupMenuItem(value: 'brightness', child: Text('Set Brightness')),
                              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Group')),
                              PopupMenuItem(
                                value: 'toggle_status',
                                child: Text(g.status.toLowerCase() == 'active' ? 'Mark Inactive' : 'Mark Active'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete Group', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildSortHeader(String title, String columnKey, DeviceManagementState state, Color primaryColor) {
    final isActive = state.groupsSortBy.toLowerCase() == columnKey.toLowerCase();
    final isAsc = state.groupsSortOrder.toLowerCase() == 'asc';
    return InkWell(
      onTap: () => ref.read(deviceManagementProvider.notifier).sortDeviceGroups(columnKey),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: isActive ? primaryColor : null,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isActive
                ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 14,
            color: isActive ? primaryColor : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // GRID VIEW
  // ============================================================================

  Widget _buildGridView(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final groups = state.groupsList;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 175,
          ),
          itemBuilder: (context, idx) {
            final g = groups[idx];
            final isSelected = state.selectedGroupId == g.id;
            final typeColor = _getGroupTypeColor(g.groupType);

            return InkWell(
              onTap: () => notifier.selectDeviceGroup(g.id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: isSelected ? 1.8 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(_getGroupTypeIcon(g.groupType), color: typeColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              Text(
                                g.locationScope.isNotEmpty ? g.locationScope : 'All Buildings',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: g.status.toLowerCase() == 'active'
                                ? const Color(0xFF059669).withValues(alpha: 0.12)
                                : const Color(0xFF64748B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            g.status.toLowerCase() == 'active' ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: g.status.toLowerCase() == 'active'
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${g.memberCount} Devices',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          g.profileName,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow_outlined, size: 18, color: Color(0xFF2563EB)),
                          onPressed: () => _openAdvancedControlDialog(g),
                          tooltip: 'Run Group Commands',
                        ),
                        IconButton(
                          icon: const Icon(Icons.people_outline, size: 16, color: Color(0xFF64748B)),
                          onPressed: () => _openMembersDialog(g),
                          tooltip: 'Manage Members',
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                          onPressed: () => _openEditDialog(g),
                          tooltip: 'Edit',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // PAGINATION FOOTER
  // ============================================================================

  Widget _buildPaginationBar(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return CampusPaginationBar(
      currentPage: state.groupsPage,
      pageSize: state.groupsPageSize,
      totalCount: state.totalGroupsCount,
      itemLabel: 'groups',
      pageSizes: const [5, 10, 20, 50, 100],
      onPageChanged: notifier.setGroupsPage,
      onPageSizeChanged: notifier.setGroupsPageSize,
    );
  }

  // ============================================================================
  // 6. RIGHT INSPECTOR PANEL ("Group Details")
  // ============================================================================

  Widget _buildRightInspectorPanel(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final group = state.selectedGroupDetail ?? (state.groupsList.isNotEmpty ? state.groupsList.first : null);

    if (group == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('Select a device group to view details.')),
      );
    }

    final typeColor = _getGroupTypeColor(group.groupType);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Title & Pop-out icon
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      'Group Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  onPressed: () => _openMembersDialog(group),
                  tooltip: 'Full Screen Inspector',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Selected Group Info Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Large icon in square
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getGroupTypeIcon(group.groupType), color: typeColor, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: group.status.toLowerCase() == 'active'
                                  ? const Color(0xFF059669).withValues(alpha: 0.12)
                                  : const Color(0xFF64748B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: group.status.toLowerCase() == 'active'
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  group.status.toLowerCase() == 'active' ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: group.status.toLowerCase() == 'active'
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  group.description.isNotEmpty
                      ? group.description
                      : 'All lights in Classrooms (Block A) with unified control, scheduling and automation.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),

                // Key Specifications
                _buildSpecRow('Group Type', group.groupType, isDark),
                _buildSpecRow('Location / Scope', group.locationScope.isNotEmpty ? group.locationScope : 'Block A > Classrooms', isDark),
                _buildSpecRow('Total Devices', '${group.memberCount}', isDark),
                _buildSpecRow('Control Profile', group.profileName.isNotEmpty ? group.profileName : 'Default Lighting', isDark),
                _buildSpecRow('Created On', group.createdOn.isNotEmpty ? group.createdOn : '10 Jan 2025, 11:20 AM', isDark),
                _buildSpecRow('Last Updated', group.lastUpdated.isNotEmpty ? group.lastUpdated : '12 Jan 2025, 02:45 PM', isDark),
              ],
            ),
          ),
          const Divider(height: 1),

          // Section: Group Members (96) + View All ->
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Group Members (${group.memberCount})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openMembersDialog(group),
                      child: const Text(
                        'View All →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Members mini breakdown table
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('Device Type', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                            SizedBox(width: 36, child: Text('Count', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                            Expanded(flex: 4, child: Text('Status', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Row 1 (e.g. Lighting 92)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Icon(_getGroupTypeIcon(group.groupType), size: 14, color: typeColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      group.groupType,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${group.onlineCount > 0 ? group.onlineCount : (group.memberCount > 4 ? group.memberCount - 4 : group.memberCount)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Wrap(
                                spacing: 4,
                                children: [
                                  Text(
                                    '● Online (${group.onlineCount > 0 ? group.onlineCount : (group.memberCount > 4 ? group.memberCount - 4 : group.memberCount)})',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                                  ),
                                  if (group.offlineCount > 0)
                                    Text(
                                      '● Offline (${group.offlineCount})',
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFFDC2626)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (group.memberCount > 4) ...[
                        const Divider(height: 1),
                        // Row 2 (e.g. Smart Switch 4)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Icon(Icons.toggle_on_outlined, size: 14, color: Color(0xFF2563EB)),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Smart Switch',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                child: Text('4', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  '● Online (4)',
                                  style: TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Section: Group Control (i)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Group Control', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 5),
                    Tooltip(
                      message: 'Commands broadcast to all ${group.memberCount} members via MQTT topic: campus/+/+/+/cmd',
                      child: const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4 Action Buttons Grid
                Row(
                  children: [
                    // Turn ON
                    Expanded(
                      child: _buildGroupControlButton(
                        title: 'Turn ON',
                        icon: Icons.power_settings_new_rounded,
                        color: const Color(0xFF059669),
                        onTap: () async {
                          final res = await notifier.executeGroupControlCommand(group.id, 'turn_on', {'power': true});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Dispatched "Turn ON" to ${res['sent_commands'] ?? group.memberCount} devices.')),
                            );
                          }
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Turn OFF
                    Expanded(
                      child: _buildGroupControlButton(
                        title: 'Turn OFF',
                        icon: Icons.power_settings_new_rounded,
                        color: const Color(0xFFDC2626),
                        onTap: () async {
                          final res = await notifier.executeGroupControlCommand(group.id, 'turn_off', {'power': false});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Dispatched "Turn OFF" to ${res['sent_commands'] ?? group.memberCount} devices.')),
                            );
                          }
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Brightness
                    Expanded(
                      child: _buildGroupControlButton(
                        title: 'Brightness',
                        icon: Icons.wb_sunny_rounded,
                        color: const Color(0xFF0284C7),
                        onTap: () => _showQuickBrightnessDialog(group),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Advanced Control
                    Expanded(
                      child: _buildGroupControlButton(
                        title: 'Advanced\nControl',
                        icon: Icons.tune_rounded,
                        color: const Color(0xFF7C3AED),
                        onTap: () => _openAdvancedControlDialog(group),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Accordion: Schedules (3)
          _buildAccordionTile(
            title: 'Schedules (${group.schedulesCount})',
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF2563EB),
            isExpanded: _isSchedulesExpanded,
            onToggle: () => setState(() => _isSchedulesExpanded = !_isSchedulesExpanded),
            isDark: isDark,
            expandedContent: Column(
              children: [
                _buildSubItemTile('Morning Prep (07:30 AM)', 'Runs Mon–Fri • Auto On (80% level)', true),
                _buildSubItemTile('Class Dismissal (03:30 PM)', 'Runs Mon–Fri • Auto Off', true),
                _buildSubItemTile('Weekend Night Sweep (10:00 PM)', 'Runs Sat–Sun • Security Lockout', true),
              ],
            ),
          ),

          // Accordion: Automation Rules (2)
          _buildAccordionTile(
            title: 'Automation Rules (${group.automationsCount})',
            icon: Icons.auto_mode_rounded,
            iconColor: const Color(0xFF059669),
            isExpanded: _isAutomationsExpanded,
            onToggle: () => setState(() => _isAutomationsExpanded = !_isAutomationsExpanded),
            isDark: isDark,
            expandedContent: Column(
              children: [
                _buildSubItemTile('Auto Off (No Occupancy 5m)', 'Triggered by PIR Sensors • Active', true),
                _buildSubItemTile('Natural Daylight Harvesting', 'Dim to 50% when Lux > 400 • Active', true),
              ],
            ),
          ),

          // Accordion: Scenes & Presets (4)
          _buildAccordionTile(
            title: 'Scenes & Presets (${group.scenesCount})',
            icon: Icons.layers_rounded,
            iconColor: const Color(0xFF7C3AED),
            isExpanded: _isScenesExpanded,
            onToggle: () => setState(() => _isScenesExpanded = !_isScenesExpanded),
            isDark: isDark,
            expandedContent: Column(
              children: [
                _buildSubItemTile('Standard Classroom (100%)', 'Applied during regular class lectures', null),
                _buildSubItemTile('Projector / Dimmed (30%)', 'Ideal for video and projector sessions', null),
                _buildSubItemTile('Exam Mode (100% Bright)', 'Strict lock on adjustments during exams', null),
                _buildSubItemTile('Energy Saver (50%)', 'Used during after-school study sessions', null),
              ],
            ),
          ),

          // Accordion: Energy & Usage
          _buildAccordionTile(
            title: 'Energy & Usage',
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFFD97706),
            isExpanded: _isEnergyExpanded,
            onToggle: () => setState(() => _isEnergyExpanded = !_isEnergyExpanded),
            isDark: isDark,
            expandedContent: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  _buildSpecRow('Current Power Load', '34.2 kW', isDark),
                  _buildSpecRow('Today Energy Consumption', '148.6 kWh', isDark),
                  _buildSpecRow('Peak Demand Hour', '11:00 AM – 12:00 PM', isDark),
                  _buildSpecRow('Efficiency Score', '96.4% (Grade A)', isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupControlButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isExpanded,
    required VoidCallback onToggle,
    required bool isDark,
    required Widget expandedContent,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) expandedContent,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSubItemTile(String name, String subtext, bool? isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                Text(subtext, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          if (isActive != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Active', style: TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  IconData _getGroupTypeIcon(String groupType) {
    final t = groupType.toLowerCase();
    if (t.contains('lighting') || t.contains('light')) return Icons.lightbulb_outline_rounded;
    if (t.contains('hvac') || t.contains('ac')) return Icons.ac_unit_rounded;
    if (t.contains('av') || t.contains('projector') || t.contains('display')) return Icons.tv_rounded;
    if (t.contains('security') || t.contains('cctv')) return Icons.shield_outlined;
    if (t.contains('network') || t.contains('wi-fi') || t.contains('wifi')) return Icons.wifi_rounded;
    if (t.contains('environment') || t.contains('fan') || t.contains('sensor')) return Icons.eco_outlined;
    if (t.contains('access') || t.contains('door') || t.contains('gate')) return Icons.lock_outline_rounded;
    if (t.contains('composite') || t.contains('smart classroom')) return Icons.dashboard_customize_outlined;
    return Icons.hub_outlined;
  }

  Color _getGroupTypeColor(String groupType) {
    final t = groupType.toLowerCase();
    if (t.contains('lighting')) return const Color(0xFFD97706); // Amber
    if (t.contains('hvac') || t.contains('ac')) return const Color(0xFF2563EB); // Blue
    if (t.contains('av') || t.contains('projector')) return const Color(0xFF7C3AED); // Purple
    if (t.contains('security') || t.contains('cctv')) return const Color(0xFFDC2626); // Red
    if (t.contains('network') || t.contains('wi-fi')) return const Color(0xFF0891B2); // Cyan
    if (t.contains('environment') || t.contains('fan') || t.contains('sensor')) return const Color(0xFF059669); // Green
    if (t.contains('access') || t.contains('door')) return const Color(0xFF4338CA); // Indigo
    if (t.contains('composite')) return const Color(0xFF4F46E5); // Blue-Violet
    return const Color(0xFF2563EB);
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      final s = n.toString();
      final len = s.length;
      return '${s.substring(0, len - 3)},${s.substring(len - 3)}';
    }
    return n.toString();
  }
}
