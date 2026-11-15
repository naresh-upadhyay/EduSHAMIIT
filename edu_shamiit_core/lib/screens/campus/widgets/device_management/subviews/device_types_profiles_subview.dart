import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device_management_models.dart';
import '../../../providers/device_management_provider.dart';
import '../dialogs/create_edit_device_type_wizard_dialog.dart';
import '../dialogs/create_edit_device_profile_dialog.dart';
import '../dialogs/deploy_device_profile_dialog.dart';

class DeviceTypesProfilesSubview extends ConsumerStatefulWidget {
  const DeviceTypesProfilesSubview({super.key});

  @override
  ConsumerState<DeviceTypesProfilesSubview> createState() => _DeviceTypesProfilesSubviewState();
}

class _DeviceTypesProfilesSubviewState extends ConsumerState<DeviceTypesProfilesSubview> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTypeIds = {};

  // Expandable tiles states
  bool _isCapConfigExpanded = false;
  bool _isDefaultSettingsExpanded = false;
  bool _isAssignedDevicesExpanded = false;

  final List<String> _categoriesFilter = [
    'All Categories',
    'Security',
    'AV & Display',
    'Network',
    'Power & Energy',
    'Building Automation',
    'Environment',
    'Safety & Fire',
    'Access Control',
  ];

  final List<String> _statusFilter = [
    'All Status',
    'Active',
    'Inactive',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceManagementProvider.notifier).loadTypesAndProfilesData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1050;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top KPI Summary Bar (24 Types, 76 Profiles, 24 Default, 52 Custom, 8,742 Mapped, 95.4% Compliance)
              _buildKpisBar(state.typesProfilesKpis, isDark),
              const SizedBox(height: 16),

              // 2. Section Header & Add Device Type button
              _buildSectionHeader(context, notifier, state),
              const SizedBox(height: 14),

              // 3. Sub-Tabs Bar (Device Types (24), Control Profiles (76), Capability Templates, Presets & Scenes)
              _buildSubTabsBar(state.typesActiveSubTab, notifier),
              const SizedBox(height: 14),

              // 4. Filters & Search Row
              _buildFiltersRow(state, notifier, isDark),
              const SizedBox(height: 14),

              // 5. Main Content Area depending on Sub-Tab
              _buildSubTabContent(state, notifier, isDark, isWide),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // 1. TOP KPI BAR
  // ============================================================================

  Widget _buildKpisBar(DeviceTypesProfilesKpis kpis, bool isDark) {
    return LayoutBuilder(
      builder: (context, c) {
        final cardWidth = c.maxWidth >= 1100
            ? (c.maxWidth - (5 * 12)) / 6
            : (c.maxWidth >= 700 ? (c.maxWidth - (2 * 12)) / 3 : (c.maxWidth - 12) / 2);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'Total Device Types',
              value: '${kpis.totalDeviceTypes}',
              icon: Icons.layers_outlined,
              iconColor: const Color(0xFF0284C7),
              bgColor: const Color(0xFFF0F9FF),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Active Profiles',
              value: '${kpis.activeProfiles}',
              icon: Icons.grid_view_rounded,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Default Profiles',
              value: '${kpis.defaultProfiles}',
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Custom Profiles',
              value: '${kpis.customProfiles}',
              icon: Icons.view_in_ar_rounded,
              iconColor: const Color(0xFF4F46E5),
              bgColor: const Color(0xFFEEF2FF),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Mapped Devices',
              value: _formatNumber(kpis.mappedDevices),
              icon: Icons.hub_outlined,
              iconColor: const Color(0xFF0891B2),
              bgColor: const Color(0xFFECFEFF),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Compliance',
              value: '${kpis.complianceRate.toStringAsFixed(1)}%',
              icon: Icons.verified_user_outlined,
              iconColor: const Color(0xFF059669),
              bgColor: const Color(0xFFECFDF5),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. SECTION HEADER
  // ============================================================================

  Widget _buildSectionHeader(BuildContext context, DeviceManagementNotifier notifier, DeviceManagementState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.layers_rounded, color: Color(0xFF2563EB), size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Types & Profiles',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Define device categories, capabilities and control profiles (default and custom) for all campus devices.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Device Type'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => CreateEditDeviceTypeWizardDialog(
                onSave: (payload) => notifier.createDeviceType(payload),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================================
  // 3. SUB-TABS BAR
  // ============================================================================

  Widget _buildSubTabsBar(String activeSubTab, DeviceManagementNotifier notifier) {
    final tabs = [
      'Device Types (24)',
      'Control Profiles (76)',
      'Capability Templates',
      'Presets & Scenes',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = activeSubTab == tab;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => notifier.setTypesSubTab(tab),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
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
  // 4. FILTERS ROW
  // ============================================================================

  Widget _buildFiltersRow(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < 750;

        return isCompact
            ? Column(
                children: [
                  _buildSearchBox(state, notifier),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildCategoryDropdown(state, notifier)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatusDropdown(state, notifier)),
                      const SizedBox(width: 8),
                      _buildViewToggles(state, notifier),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildSearchBox(state, notifier),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: _buildCategoryDropdown(state, notifier),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: _buildStatusDropdown(state, notifier),
                  ),
                  const SizedBox(width: 12),
                  _buildViewToggles(state, notifier),
                ],
              );
      },
    );
  }

  Widget _buildSearchBox(DeviceManagementState state, DeviceManagementNotifier notifier) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    notifier.setTypesSearchQuery('');
                  },
                )
              : null,
          hintText: 'Search device types (e.g., CCTV, AC, Lighting...)',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onSubmitted: (val) => notifier.setTypesSearchQuery(val),
      ),
    );
  }

  Widget _buildCategoryDropdown(DeviceManagementState state, DeviceManagementNotifier notifier) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.typesFilterCategory,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          items: _categoriesFilter.map((cat) {
            return DropdownMenuItem<String>(
              value: cat,
              child: Text(cat, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) notifier.setTypesFilterCategory(val);
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(DeviceManagementState state, DeviceManagementNotifier notifier) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.typesFilterStatus,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          items: _statusFilter.map((st) {
            return DropdownMenuItem<String>(
              value: st,
              child: Text(st, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) notifier.setTypesFilterStatus(val);
          },
        ),
      ),
    );
  }

  Widget _buildViewToggles(DeviceManagementState state, DeviceManagementNotifier notifier) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: state.typesIsGridView ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            splashRadius: 18,
            tooltip: 'Grid View',
            onPressed: () => notifier.toggleTypesGridView(true),
          ),
          Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
          IconButton(
            icon: Icon(
              Icons.view_list_rounded,
              size: 18,
              color: !state.typesIsGridView ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            splashRadius: 18,
            tooltip: 'Table / List View',
            onPressed: () => notifier.toggleTypesGridView(false),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 5. MAIN CONTENT AREA
  // ============================================================================

  Widget _buildSubTabContent(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
    bool isWide,
  ) {
    final subTab = state.typesActiveSubTab;

    if (subTab.contains('Control Profiles')) {
      return _buildAllProfilesView(state, notifier, isDark);
    } else if (subTab.contains('Capability Templates')) {
      return _buildCapabilityTemplatesView(state, notifier, isDark);
    } else if (subTab.contains('Presets & Scenes')) {
      return _buildPresetsScenesView(state, notifier, isDark);
    }

    // Default: Device Types (24) with Table & Right Inspector
    if (state.isTypesLoading && state.deviceTypesList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Device Types Table
          Expanded(
            flex: 62,
            child: _buildDeviceTypesTableCard(state, notifier, isDark),
          ),
          const SizedBox(width: 16),

          // Right Side: Device Type Details Inspector
          Expanded(
            flex: 38,
            child: _buildDeviceTypeDetailsCard(state, notifier, isDark),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDeviceTypesTableCard(state, notifier, isDark),
          const SizedBox(height: 16),
          _buildDeviceTypeDetailsCard(state, notifier, isDark),
        ],
      );
    }
  }

  // ============================================================================
  // DEVICE TYPES TABLE (LEFT)
  // ============================================================================

  Widget _buildDeviceTypesTableCard(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final types = state.deviceTypesList;
    final selectedId = state.selectedDeviceTypeId;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Bulk Actions Bar (Multiselect functionality)
          if (_selectedTypeIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: primaryColor.withValues(alpha: 0.2))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedTypeIds.length} of ${types.length} selected',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Activate Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.check, size: 14, color: Color(0xFF16A34A)),
                      label: const Text('Activate', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFF86EFAC)),
                      ),
                      onPressed: () async {
                        await notifier.bulkUpdateDeviceTypesStatus(_selectedTypeIds.toList(), true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Activated ${_selectedTypeIds.length} device type(s)')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Deactivate Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.block, size: 14, color: Color(0xFFD97706)),
                      label: const Text('Deactivate', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFFFCD34D)),
                      ),
                      onPressed: () async {
                        await notifier.bulkUpdateDeviceTypesStatus(_selectedTypeIds.toList(), false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Deactivated ${_selectedTypeIds.length} device type(s)')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Delete Selected Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                      label: const Text('Delete', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                      ),
                      onPressed: () async {
                        final count = _selectedTypeIds.length;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Selected Device Types?'),
                            content: Text('Are you sure you want to delete $count selected device type(s)?'),
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
                          await notifier.bulkDeleteDeviceTypes(_selectedTypeIds.toList());
                          setState(() => _selectedTypeIds.clear());
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$count device type(s) deleted successfully')),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Deselect All
                    TextButton(
                      onPressed: () => setState(() => _selectedTypeIds.clear()),
                      child: Text('Deselect All', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ),
                  ],
                ),
              ),
            ),

          // Table Layout
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 700),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowHeight: 40,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                horizontalMargin: 16,
                columnSpacing: 18,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                headingTextStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  letterSpacing: 0.3,
                ),
                columns: [
                  DataColumn(
                    label: Checkbox(
                      value: _selectedTypeIds.isNotEmpty && _selectedTypeIds.length == types.length,
                      tristate: _selectedTypeIds.isNotEmpty && _selectedTypeIds.length < types.length,
                      activeColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedTypeIds.addAll(types.map((t) => t.id));
                          } else {
                            _selectedTypeIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const DataColumn(label: Text('Device Type ↑')),
                  const DataColumn(label: Text('Category')),
                  const DataColumn(label: Text('Mapped Devices')),
                  const DataColumn(label: Text('Profiles')),
                  const DataColumn(label: Text('Status')),
                  const DataColumn(label: Text('Last Updated')),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: types.map((dt) {
                  final isRowSelected = dt.id == selectedId;
                  final isChecked = _selectedTypeIds.contains(dt.id);

                  return DataRow(
                    selected: isRowSelected,
                    onSelectChanged: (_) => notifier.selectDeviceType(dt.id),
                    color: WidgetStateProperty.resolveWith((states) {
                      if (isRowSelected) return primaryColor.withValues(alpha: isDark ? 0.25 : 0.08);
                      if (states.contains(WidgetState.hovered)) return isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF8FAFC);
                      return isDark ? const Color(0xFF1E293B) : Colors.white;
                    }),
                    cells: [
                      DataCell(
                        Checkbox(
                          value: isChecked,
                          activeColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedTypeIds.add(dt.id);
                              } else {
                                _selectedTypeIds.remove(dt.id);
                              }
                            });
                          },
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                              ),
                              child: Icon(
                                _resolveTypeIcon(dt.icon),
                                size: 18,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dt.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (dt.description.isNotEmpty)
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      dt.description,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(_buildCategoryBadge(dt.categoryName)),
                      DataCell(
                        Text(
                          _formatNumber(dt.mappedDevicesCount),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${dt.profilesCount}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ),
                      DataCell(_buildActiveStatusPill(dt.status)),
                      DataCell(
                        Text(
                          dt.updatedAt ?? '12 Jan 2025, 10:24 AM',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                              splashRadius: 16,
                              tooltip: 'Edit Device Type',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => CreateEditDeviceTypeWizardDialog(
                                    initialType: dt,
                                    onSave: (payload) => notifier.updateDeviceType(dt.id, payload),
                                  ),
                                );
                              },
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                              splashRadius: 16,
                              onSelected: (action) {
                                if (action == 'duplicate') {
                                  notifier.duplicateDeviceType(dt.id);
                                } else if (action == 'delete') {
                                  _confirmDeleteType(context, dt, notifier);
                                } else if (action == 'add_profile') {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => CreateEditDeviceProfileDialog(
                                      defaultDeviceTypeId: dt.id,
                                      defaultDeviceTypeName: dt.name,
                                      onSave: (payload) => notifier.createDeviceProfile(payload),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'add_profile',
                                  child: Text('Add Control Profile', style: TextStyle(fontSize: 12)),
                                ),
                                const PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('Duplicate Device Type', style: TextStyle(fontSize: 12)),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete / Deactivate', style: TextStyle(fontSize: 12, color: Colors.red)),
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

          // Pagination Footer matching screenshot
          _buildPaginationFooter(state, notifier),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String categoryName) {
    Color bg = const Color(0xFFEFF6FF);
    Color border = const Color(0xFFBFDBFE);
    Color text = const Color(0xFF1D4ED8);
    IconData icon = Icons.circle_outlined;

    final lower = categoryName.toLowerCase();
    if (lower.contains('security')) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFCA5A5);
      text = const Color(0xFFDC2626);
      icon = Icons.shield_outlined;
    } else if (lower.contains('av') || lower.contains('display')) {
      bg = const Color(0xFFFAF5FF);
      border = const Color(0xFFE9D5FF);
      text = const Color(0xFF9333EA);
      icon = Icons.play_circle_outline_rounded;
    } else if (lower.contains('network')) {
      bg = const Color(0xFFEFF6FF);
      border = const Color(0xFFBFDBFE);
      text = const Color(0xFF2563EB);
      icon = Icons.wifi_rounded;
    } else if (lower.contains('power') || lower.contains('energy')) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFD97706);
      icon = Icons.bolt_rounded;
    } else if (lower.contains('building') || lower.contains('automation')) {
      bg = const Color(0xFFF0F9FF);
      border = const Color(0xFFBAE6FD);
      text = const Color(0xFF0284C7);
      icon = Icons.corporate_fare_rounded;
    } else if (lower.contains('environment')) {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      text = const Color(0xFF059669);
      icon = Icons.eco_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            categoryName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStatusPill(String status) {
    final isActive = status.toLowerCase() == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
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
              color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(DeviceManagementState state, DeviceManagementNotifier notifier) {
    final currentPage = state.deviceTypesPage;
    final totalPages = state.deviceTypesTotalPages;
    final total = state.totalDeviceTypes;
    final startIdx = total == 0 ? 0 : ((currentPage - 1) * state.deviceTypesPageSize) + 1;
    final endIdx = total == 0
        ? 0
        : (currentPage * state.deviceTypesPageSize > total
            ? total
            : currentPage * state.deviceTypesPageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Showing $startIdx – $endIdx of $total device types',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 24),
            Row(
              children: [
                const Text('Rows per page:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('10', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  splashRadius: 16,
                  onPressed: currentPage > 1 ? () => notifier.setTypesPage(currentPage - 1) : null,
                ),
                for (int i = 1; i <= totalPages; i++)
                  InkWell(
                    onTap: () => notifier.setTypesPage(i),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentPage == i ? const Color(0xFF2563EB) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$i',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: currentPage == i ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  splashRadius: 16,
                  onPressed: currentPage < totalPages ? () => notifier.setTypesPage(currentPage + 1) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // DEVICE TYPE DETAILS INSPECTOR (RIGHT)
  // ============================================================================

  Widget _buildDeviceTypeDetailsCard(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final type = state.selectedDeviceTypeDetail;
    if (type == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('Select a device type from the table to view specs and profiles.'),
        ),
      );
    }

    final profiles = type.profiles.isNotEmpty ? type.profiles : state.deviceProfilesList;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.dvr_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Text(
                  'Device Type Details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF64748B)),
                  splashRadius: 16,
                  tooltip: 'Full Details',
                  onPressed: () {},
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top device snapshot
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(
                        _resolveTypeIcon(type.icon),
                        size: 30,
                        color: const Color(0xFF2563EB),
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
                                type.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildCategoryBadge(type.categoryName),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            type.description.isNotEmpty ? type.description : 'IP/Network surveillance cameras',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          _buildActiveStatusPill(type.status),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick Specs
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildSpecRow('System Category', type.systemCategory),
                      const SizedBox(height: 8),
                      _buildSpecRow('Total Mapped Devices', _formatNumber(type.mappedDevicesCount)),
                      const SizedBox(height: 8),
                      _buildSpecRow('Control Profiles', '${type.profilesCount} (2 Default, 4 Custom)'),
                      const SizedBox(height: 8),
                      _buildSpecRow('Supported Protocols', type.supportedProtocols.join(', ')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Capabilities wrap
                const Text(
                  'Capabilities',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (type.defaultCapabilities.isNotEmpty
                          ? type.defaultCapabilities
                          : ['Live View', 'PTZ Control', 'Recording', 'Snapshot', 'Motion Alert', 'Stream Share'])
                      .map((cap) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        cap,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),

                // Control Profiles Header with + Add Profile button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          'Control Profiles (${profiles.length})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Add Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => CreateEditDeviceProfileDialog(
                            defaultDeviceTypeId: type.id,
                            defaultDeviceTypeName: type.name,
                            onSave: (payload) => notifier.createDeviceProfile(payload),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Control Profiles Mini Table matching screenshot
                _buildControlProfilesMiniTable(profiles, type, notifier, context),

                const SizedBox(height: 14),

                // Expandable Accordions:
                // 1. Capability Configuration
                _buildAccordionTile(
                  icon: Icons.settings_suggest_rounded,
                  title: 'Capability Configuration',
                  isExpanded: _isCapConfigExpanded,
                  onToggle: () => setState(() => _isCapConfigExpanded = !_isCapConfigExpanded),
                  content: _buildCapConfigContent(type),
                ),
                const SizedBox(height: 8),

                // 2. Default Settings
                _buildAccordionTile(
                  icon: Icons.sync_alt_rounded,
                  title: 'Default Settings',
                  isExpanded: _isDefaultSettingsExpanded,
                  onToggle: () => setState(() => _isDefaultSettingsExpanded = !_isDefaultSettingsExpanded),
                  content: _buildDefaultSettingsContent(type),
                ),
                const SizedBox(height: 8),

                // 3. Assigned Devices
                _buildAccordionTile(
                  icon: Icons.devices_rounded,
                  title: 'Assigned Devices (${_formatNumber(type.mappedDevicesCount)})',
                  isExpanded: _isAssignedDevicesExpanded,
                  onToggle: () => setState(() => _isAssignedDevicesExpanded = !_isAssignedDevicesExpanded),
                  content: _buildAssignedDevicesContent(type),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildControlProfilesMiniTable(
    List<DeviceProfileItem> profiles,
    DeviceTypeDetailItem type,
    DeviceManagementNotifier notifier,
    BuildContext context,
  ) {
    if (profiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text('No control profiles configured.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Profile Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('Type', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('Usage', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                SizedBox(width: 24),
              ],
            ),
          ),

          // Rows
          for (final p in profiles.take(6)) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      p.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.isDefault ? const Color(0xFFEFF6FF) : const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.isDefault ? 'Default' : 'Custom',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: p.isDefault ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${p.usageCount}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _buildActiveStatusPill(p.status),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 14, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                    onSelected: (action) {
                      if (action == 'deploy') {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => DeployDeviceProfileDialog(
                            profile: p,
                            deviceType: type,
                            onDeploy: (payload) => notifier.deployDeviceProfile(p.id, payload),
                          ),
                        );
                      } else if (action == 'duplicate') {
                        notifier.duplicateDeviceProfile(p.id);
                      } else if (action == 'edit') {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => CreateEditDeviceProfileDialog(
                            initialProfile: p,
                            defaultDeviceTypeId: type.id,
                            defaultDeviceTypeName: type.name,
                            onSave: (payload) => notifier.updateDeviceProfile(p.id, payload),
                          ),
                        );
                      } else if (action == 'delete') {
                        _confirmDeleteProfile(context, p, notifier);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'deploy', child: Text('Deploy to Devices', style: TextStyle(fontSize: 12))),
                      const PopupMenuItem(value: 'edit', child: Text('Edit Profile', style: TextStyle(fontSize: 12))),
                      const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Profile', style: TextStyle(fontSize: 12))),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Profile', style: TextStyle(fontSize: 12, color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccordionTile({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: content,
            ),
        ],
      ),
    );
  }

  Widget _buildCapConfigContent(DeviceTypeDetailItem type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Telemetry Topics & Payload Mapping:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Topic: campus/telemetry/${type.code}/+\nState: campus/state/${type.code}/+\nCommand: campus/cmd/${type.code}/+',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF38BDF8)),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultSettingsContent(DeviceTypeDetailItem type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSpecRow('Default Power State', 'Offline / Low Power'),
        const SizedBox(height: 6),
        _buildSpecRow('Heartbeat Frequency', 'Every 30 seconds'),
        const SizedBox(height: 6),
        _buildSpecRow('Max Telemetry Buffer', '500 packets'),
      ],
    );
  }

  Widget _buildAssignedDevicesContent(DeviceTypeDetailItem type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sample Devices Mapped to ${type.name}:',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        for (int i = 1; i <= 3; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Text(
                  '${type.code.toUpperCase()}-B1-F1-10$i (Room 10$i)',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================================
  // TAB 2: ALL CONTROL PROFILES VIEW
  // ============================================================================

  Widget _buildAllProfilesView(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final profiles = state.deviceProfilesList;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Control Profiles (${profiles.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => CreateEditDeviceProfileDialog(
                      availableDeviceTypes: state.deviceTypesList,
                      onSave: (payload) => notifier.createDeviceProfile(payload),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Profile Name')),
                DataColumn(label: Text('Device Type')),
                DataColumn(label: Text('Profile Type')),
                DataColumn(label: Text('Version')),
                DataColumn(label: Text('Mapped Usage')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: profiles.map((p) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ),
                    DataCell(
                      Text(p.deviceTypeName ?? 'General', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.isDefault ? const Color(0xFFEFF6FF) : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.isDefault ? 'Default' : 'Custom',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: p.isDefault ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(p.version, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                    DataCell(Text('${p.usageCount} devices', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(_buildActiveStatusPill(p.status)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEFF6FF),
                              foregroundColor: const Color(0xFF2563EB),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            child: const Text('Deploy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => DeployDeviceProfileDialog(
                                  profile: p,
                                  onDeploy: (payload) => notifier.deployDeviceProfile(p.id, payload),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                            splashRadius: 16,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => CreateEditDeviceProfileDialog(
                                  initialProfile: p,
                                  availableDeviceTypes: state.deviceTypesList,
                                  onSave: (payload) => notifier.updateDeviceProfile(p.id, payload),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 3: CAPABILITY TEMPLATES VIEW
  // ============================================================================

  Widget _buildCapabilityTemplatesView(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final caps = state.capabilitiesLibrary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capability Templates Catalog',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(
                'Standard UI Controls & Schema Library',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 2.2,
            ),
            itemCount: caps.length,
            itemBuilder: (context, idx) {
              final cap = caps[idx];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(_resolveTypeIcon(cap.icon), size: 18, color: const Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cap.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                cap.category,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cap.type.toUpperCase(),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cap.description,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 4: PRESETS & SCENES VIEW
  // ============================================================================

  Widget _buildPresetsScenesView(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final scenes = state.scenes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Configured Presets & Operational Scenes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 2.2,
            ),
            itemCount: scenes.length,
            itemBuilder: (context, idx) {
              final scene = scenes[idx];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.palette_rounded, size: 22, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            scene.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            scene.description,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPERS & MODALS
  // ============================================================================

  void _confirmDeleteType(BuildContext context, DeviceTypeDetailItem dt, DeviceManagementNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete / Deactivate ${dt.name}?'),
        content: Text(
          'Are you sure you want to delete or deactivate "${dt.name}"? If devices are mapped, it will be marked as inactive.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await notifier.deleteDeviceType(dt.id);
            },
            child: const Text('Confirm Deactivation'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProfile(BuildContext context, DeviceProfileItem p, DeviceManagementNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive Profile ${p.name}?'),
        content: Text('Are you sure you want to archive profile "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await notifier.deleteDeviceProfile(p.id);
            },
            child: const Text('Archive Profile'),
          ),
        ],
      ),
    );
  }

  IconData _resolveTypeIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'videocam':
      case 'camera':
      case 'cctv':
        return Icons.videocam_rounded;
      case 'projector':
        return Icons.tv_rounded;
      case 'smart_display':
      case 'interactive_display':
        return Icons.desktop_windows_rounded;
      case 'wifi':
      case 'router':
        return Icons.wifi_rounded;
      case 'power':
      case 'plug':
        return Icons.electrical_services_rounded;
      case 'lightbulb':
      case 'lighting':
        return Icons.lightbulb_outline_rounded;
      case 'volume_up':
      case 'speaker':
      case 'audio':
        return Icons.volume_up_rounded;
      case 'ac':
      case 'hvac':
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'fan':
        return Icons.wind_power_rounded;
      case 'sensors':
      case 'sensor':
        return Icons.sensors_rounded;
      case 'door':
      case 'lock':
        return Icons.lock_outline_rounded;
      case 'fence':
      case 'gate':
        return Icons.fence_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  String _formatNumber(num value) {
    final s = value.toString();
    final parts = s.split('.');
    final whole = parts[0];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return formatted;
  }
}
