import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device_management_models.dart';
import '../../providers/device_management_provider.dart';
import 'device_management_kpis_bar.dart';
import 'device_management_left_panel.dart';
import 'device_overview_card.dart';
import 'devices_by_type_donut_card.dart';
import 'device_quick_controls_card.dart';
import 'device_live_control_table.dart';
import 'device_location_explorer_card.dart';
import 'device_energy_usage_card.dart';
import 'device_active_automations_card.dart';
import 'device_scenes_presets_card.dart';
import 'device_recent_alerts_card.dart';
import 'dialogs/add_device_wizard_dialog.dart';
import 'dialogs/device_details_drawer.dart';
import 'dialogs/device_filter_dialog.dart';
import 'dialogs/create_scene_dialog.dart';
import 'subviews/device_groups_subview.dart';
import 'subviews/device_automations_subview.dart';
import 'subviews/device_schedules_subview.dart';
import 'subviews/device_audit_logs_subview.dart';
import 'subviews/device_types_profiles_subview.dart';
import 'subviews/device_locations_mapping_subview.dart';
import 'subviews/device_live_control_subview.dart';
import 'subviews/device_bulk_operations_subview.dart';
import 'subviews/device_scenes_presets_subview.dart';
import 'subviews/device_energy_usage_subview.dart';
import 'subviews/device_health_diagnostics_subview.dart';
import 'subviews/device_integrations_gateways_subview.dart';
import 'subviews/device_access_permissions_subview.dart';
import 'subviews/device_import_export_subview.dart';
import 'subviews/device_registry_subview.dart';

class DeviceManagementTabView extends ConsumerStatefulWidget {
  const DeviceManagementTabView({super.key});

  @override
  ConsumerState<DeviceManagementTabView> createState() => _DeviceManagementTabViewState();
}

class _DeviceManagementTabViewState extends ConsumerState<DeviceManagementTabView> {
  DeviceItemModel? _inspectedDevice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceManagementProvider.notifier).loadAll();
    });
  }

  void _openAddDeviceWizard() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddDeviceWizardDialog(
        onSaved: () {
          ref.read(deviceManagementProvider.notifier).loadAll();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device registered successfully!')),
          );
        },
      ),
    );
  }

  void _openFilterDialog() {
    final state = ref.read(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);
    showDialog(
      context: context,
      builder: (_) => DeviceFilterDialog(
        initialBuilding: state.filterBuilding,
        initialType: state.filterType,
        initialStatus: state.filterStatus,
        buildings: state.buildingsBreakdown,
        types: state.devicesByType,
        onApply: (bld, type, status) {
          notifier.setFilterBuilding(bld);
          notifier.setFilterType(type);
          notifier.setFilterStatus(status);
        },
      ),
    );
  }

  void _openCreateSceneDialog() {
    showDialog(
      context: context,
      builder: (_) => CreateCustomSceneDialog(
        onSave: (name, code, desc) async {
          await ref.read(deviceManagementProvider.notifier).createCustomScene(name, code, desc);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scene "$name" created successfully!')),
            );
          }
        },
      ),
    );
  }

  void _rebootDevice(DeviceItemModel device) async {
    await ref.read(deviceManagementProvider.notifier).rebootDevice(device.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reboot command dispatched to ${device.deviceName} via MQTT!'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    }
  }

  void _confirmDeleteDevice(DeviceItemModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${device.deviceName}?'),
        content: const Text('Are you sure you want to remove this device from campus management?'),
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
      await ref.read(deviceManagementProvider.notifier).deleteDevice(device.id);
      ref.read(deviceManagementProvider.notifier).loadDevices();
    }
  }

  void _confirmBulkDelete(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
  ) async {
    final count = state.selectedDeviceIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count Selected Devices?'),
        content: Text(
          'Are you sure you want to remove these $count devices from campus database? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Devices'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.bulkDeleteSelectedDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count devices removed successfully!'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Widget _buildTable(DeviceManagementState state, DeviceManagementNotifier notifier) {
    return DeviceLiveControlTable(
      devices: state.devices,
      isLoading: state.isDevicesLoading,
      activeTab: state.activeTableTab,
      onTabChanged: notifier.setTableTab,
      searchQuery: state.searchQuery,
      onSearchChanged: notifier.setSearchQuery,
      selectedDeviceIds: state.selectedDeviceIds,
      onToggleSelect: notifier.toggleSelectDevice,
      onToggleSelectAll: notifier.toggleSelectAll,
      onTogglePower: notifier.toggleDevicePower,
      onSetTemperature: notifier.setDeviceTemperature,
      onSetHvacMode: notifier.setDeviceHvacMode,
      onSetFanSpeed: notifier.setDeviceFanSpeed,
      onSetBrightness: notifier.setDeviceBrightness,
      onSetProjectorInput: notifier.setDeviceProjectorInput,
      onSetProjectorVolume: notifier.setDeviceProjectorVolume,
      onGateControl: notifier.toggleGateLock,
      onInspectDevice: (d) => setState(() => _inspectedDevice = d),
      onDeleteDevice: _confirmDeleteDevice,
      onRebootDevice: _rebootDevice,
      onOpenFilters: _openFilterDialog,
      currentPage: state.currentPage,
      pageSize: state.pageSize,
      totalCount: state.totalDevices,
      onPageChanged: notifier.setPage,
      onPageSizeChanged: notifier.setPageSize,
      sortColumn: state.sortColumn,
      sortAscending: state.sortAscending,
      onSortChanged: notifier.setSorting,
      activeLocationBreadcrumb: state.selectedLocationBreadcrumb,
      onClearLocation: notifier.clearLocationFilter,
      activeTypeFilter: state.filterType,
      onClearType: () => notifier.setFilterType(null),
      activeStatusFilter: state.filterStatus,
      onClearStatus: () => notifier.setFilterStatus(null),
      onResetAllFilters: notifier.resetAllFilters,
      onBulkPowerToggle: notifier.bulkPowerToggle,
      onBulkReboot: notifier.bulkReboot,
      onBulkDelete: () => _confirmBulkDelete(state, notifier),
      onClearSelection: notifier.clearSelectedDevices,
    );
  }

  Widget _buildLocationExplorer(DeviceManagementState state, DeviceManagementNotifier notifier) {
    return DeviceLocationExplorerCard(
      tree: state.locationTree,
      selectedNodeId: state.selectedLocationNodeId,
      selectedBreadcrumb: state.selectedLocationBreadcrumb,
      onLocationSelected: (bld, fl, rm, nodeId, breadcrumb) => notifier.setFilterLocation(
        buildingId: bld,
        floorId: fl,
        roomId: rm,
        nodeId: nodeId,
        breadcrumb: breadcrumb,
      ),
      onClearLocation: notifier.clearLocationFilter,
    );
  }

  void _handleQuickControlAction(
    String action,
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
  ) {
    switch (action) {
      case 'Turn ON':
      case 'Turn OFF':
        _confirmPowerAction(action, state, notifier);
        break;
      case 'Set Level':
        _showSetLevelDialog(state, notifier);
        break;
      case 'Set Temperature':
        _showSetTemperatureDialog(state, notifier);
        break;
      case 'Apply Scene':
        _showApplySceneDialog(state, notifier);
        break;
      case 'Power Supply':
        _showPowerSupplyDialog(state, notifier);
        break;
      default:
        notifier.executeQuickControl(action);
    }
  }

  void _confirmPowerAction(
    String action,
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
  ) {
    final count = state.selectedDeviceIds.isNotEmpty
        ? state.selectedDeviceIds.length
        : state.devices.length;
    final targetDesc = state.selectedDeviceIds.isNotEmpty
        ? '$count selected device(s)'
        : 'all $count devices on campus';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              action == 'Turn ON' ? Icons.power_settings_new_rounded : Icons.power_off_rounded,
              color: action == 'Turn ON' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Text('$action Devices'),
          ],
        ),
        content: Text(
          'Are you sure you want to $action $targetDesc? This command will be broadcast immediately via MQTT.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'Turn ON' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.executeQuickControl(action);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$action command dispatched for $targetDesc'),
                  backgroundColor: action == 'Turn ON' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              );
            },
            child: Text('Confirm $action'),
          ),
        ],
      ),
    );
  }

  void _showSetLevelDialog(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
  ) {
    double level = 75.0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: Color(0xFFEAB308)),
              SizedBox(width: 8),
              Text('Quick Control: Set Brightness / Level'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adjust power output/brightness for ${state.selectedDeviceIds.isNotEmpty ? "${state.selectedDeviceIds.length} selected devices" : "all controllable devices"}:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Level:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('${level.toInt()}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF2563EB))),
                ],
              ),
              Slider(
                value: level,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${level.toInt()}%',
                onChanged: (val) => setDialogState(() => level = val),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [25, 50, 75, 100].map((v) {
                  return ActionChip(
                    label: Text('$v%'),
                    backgroundColor: level.toInt() == v ? const Color(0xFF2563EB) : null,
                    labelStyle: TextStyle(
                      color: level.toInt() == v ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onPressed: () => setDialogState(() => level = v.toDouble()),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                notifier.executeQuickControlWithParams('Set Level', {
                  'level': level.toInt(),
                  'brightness': level.toInt(),
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Level set to ${level.toInt()}% via MQTT')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: const Text('Apply Level'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetTemperatureDialog(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
  ) {
    double temp = 22.0;
    String mode = 'Cool';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.thermostat_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Quick Control: Campus Temperature'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set HVAC / AC target temperature across ${state.selectedDeviceIds.isNotEmpty ? "${state.selectedDeviceIds.length} selected devices" : "all classrooms and halls"}:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Target Temperature:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('${temp.toStringAsFixed(1)}°C', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0284C7))),
                ],
              ),
              Slider(
                value: temp,
                min: 16,
                max: 30,
                divisions: 28,
                label: '${temp.toStringAsFixed(1)}°C',
                onChanged: (val) => setDialogState(() => temp = val),
              ),
              const SizedBox(height: 12),
              const Text('HVAC Operating Mode:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['Cool', 'Heat', 'Auto', 'Eco', 'Fan Only'].map((m) {
                  final isSel = mode == m;
                  return ChoiceChip(
                    label: Text(m),
                    selected: isSel,
                    selectedColor: const Color(0xFF0284C7),
                    labelStyle: TextStyle(color: isSel ? Colors.white : null, fontWeight: FontWeight.w600),
                    onSelected: (val) {
                      if (val) setDialogState(() => mode = m);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                notifier.executeQuickControlWithParams('Set Temperature', {
                  'temperature': temp,
                  'mode': mode,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Target temperature set to ${temp.toStringAsFixed(1)}°C ($mode mode)')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
              child: const Text('Apply Temperature'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplySceneDialog(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
  ) {
    DeviceSceneItem? selectedScene = state.scenes.isNotEmpty ? state.scenes.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF9333EA)),
              SizedBox(width: 8),
              Text('Apply Preset Scene'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select an operational preset to apply immediately across campus devices:'),
                const SizedBox(height: 12),
                if (state.scenes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No scenes configured. Create a custom scene first!'),
                  )
                else
                  ...state.scenes.map((s) {
                    final isSel = selectedScene?.id == s.id;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedScene = s),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFAF5FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? const Color(0xFF9333EA) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.palette_rounded, color: isSel ? const Color(0xFF9333EA) : const Color(0xFF64748B), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: TextStyle(fontWeight: FontWeight.w700, color: isSel ? const Color(0xFF9333EA) : null)),
                                  if (s.description.isNotEmpty)
                                    Text(s.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            if (isSel)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF9333EA), size: 18),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedScene == null
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      notifier.executeScene(selectedScene!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Scene "${selectedScene!.name}" applied successfully!')),
                      );
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), foregroundColor: Colors.white),
              child: const Text('Activate Scene'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPowerSupplyDialog(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
  ) {
    String profile = 'Balanced';
    final profiles = [
      {'name': 'Eco Mode', 'desc': 'Minimizes idle power, throttles HVAC to 24°C, dims ambient lighting to 60%.', 'color': const Color(0xFF16A34A)},
      {'name': 'Balanced', 'desc': 'Standard campus daytime operation with optimal comfort and efficiency.', 'color': const Color(0xFFD97706)},
      {'name': 'High Performance', 'desc': 'Full power delivery for laboratories, auditorium events, and examinations.', 'color': const Color(0xFFDC2626)},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Power Supply Profile'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select an institutional energy policy profile for power distribution:'),
                const SizedBox(height: 12),
                ...profiles.map((p) {
                  final isSel = profile == p['name'];
                  return InkWell(
                    onTap: () => setDialogState(() => profile = p['name'] as String),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSel ? (p['color'] as Color).withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? (p['color'] as Color) : const Color(0xFFE2E8F0),
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.speed_rounded, color: p['color'] as Color, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'] as String,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: isSel ? (p['color'] as Color) : null),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p['desc'] as String,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          if (isSel)
                            Icon(Icons.check_circle_rounded, color: p['color'] as Color, size: 18),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                notifier.executeQuickControlWithParams('Power Supply', {'profile': profile});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Power profile updated to "$profile" across campus')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
              child: const Text('Set Power Profile'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            final isTablet = constraints.maxWidth >= 800 && constraints.maxWidth < 1200;

            if (isMobile) {
              return _buildMobileLayout(state, notifier, isDark);
            } else if (isTablet) {
              return _buildTabletLayout(state, notifier, isDark);
            }
            return _buildDesktopLayout(state, notifier, isDark);
          },
        ),

        // Device details inspection drawer with full CRUD & Type-Specific Controls
        if (_inspectedDevice != null)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: DeviceDetailsDrawer(
              device: _inspectedDevice!,
              onClose: () => setState(() => _inspectedDevice = null),
              onTogglePower: () {
                notifier.toggleDevicePower(_inspectedDevice!);
                setState(() {
                  _inspectedDevice = _inspectedDevice!.copyWith(
                    powerState: !_inspectedDevice!.powerState,
                  );
                });
              },
              onSetTemperature: (temp) {
                notifier.setDeviceTemperature(_inspectedDevice!, temp);
                final cur = Map<String, dynamic>.from(_inspectedDevice!.currentState);
                cur['temperature'] = temp;
                setState(() => _inspectedDevice = _inspectedDevice!.copyWith(currentState: cur));
              },
              onSetHvacMode: (mode) {
                notifier.setDeviceHvacMode(_inspectedDevice!, mode);
                final cur = Map<String, dynamic>.from(_inspectedDevice!.currentState);
                cur['mode'] = mode;
                setState(() => _inspectedDevice = _inspectedDevice!.copyWith(currentState: cur));
              },
              onSetFanSpeed: (speed) {
                notifier.setDeviceFanSpeed(_inspectedDevice!, speed);
                final cur = Map<String, dynamic>.from(_inspectedDevice!.currentState);
                cur['speed'] = speed;
                cur['fan_speed'] = speed;
                setState(() => _inspectedDevice = _inspectedDevice!.copyWith(currentState: cur));
              },
              onSetBrightness: (brightness) {
                notifier.setDeviceBrightness(_inspectedDevice!, brightness);
                final cur = Map<String, dynamic>.from(_inspectedDevice!.currentState);
                cur['brightness'] = brightness;
                setState(() => _inspectedDevice = _inspectedDevice!.copyWith(currentState: cur));
              },
              onSetProjectorInput: (input) {
                notifier.setDeviceProjectorInput(_inspectedDevice!, input);
                final cur = Map<String, dynamic>.from(_inspectedDevice!.currentState);
                cur['input'] = input;
                setState(() => _inspectedDevice = _inspectedDevice!.copyWith(currentState: cur));
              },
              onSetProjectorVolume: (volume) {
                notifier.setDeviceProjectorVolume(_inspectedDevice!, volume);
                final cur = Map<String, dynamic>.from(_inspectedDevice!.currentState);
                cur['volume'] = volume;
                setState(() => _inspectedDevice = _inspectedDevice!.copyWith(currentState: cur));
              },
              onGateControl: (action) {
                notifier.toggleGateLock(_inspectedDevice!, action);
                final cur = Map<String, dynamic>.from(_inspectedDevice!.currentState);
                if (action == 'Open') cur['position'] = 'Open';
                if (action == 'Close') cur['position'] = 'Closed';
                if (action == 'Lock') cur['locked'] = true;
                if (action == 'Unlock') cur['locked'] = false;
                setState(() => _inspectedDevice = _inspectedDevice!.copyWith(currentState: cur));
              },
              onReboot: () => _rebootDevice(_inspectedDevice!),
              onPing: () => notifier.pingDevice(_inspectedDevice!.id),
              onUpdateDevice: (data) async {
                await notifier.updateDevice(_inspectedDevice!.id, data);
                if (mounted) {
                  setState(() {
                    _inspectedDevice = _inspectedDevice!.copyWith(
                      deviceName: data['device_name']?.toString() ?? _inspectedDevice!.deviceName,
                      ipAddress: data['ip_address']?.toString() ?? _inspectedDevice!.ipAddress,
                      macAddress: data['mac_address']?.toString() ?? _inspectedDevice!.macAddress,
                      ratedPowerWatts: (data['rated_power_watts'] as num?)?.toDouble() ?? _inspectedDevice!.ratedPowerWatts,
                      notes: data['notes']?.toString() ?? _inspectedDevice!.notes,
                    );
                  });
                }
              },
              onDelete: () {
                final d = _inspectedDevice!;
                setState(() => _inspectedDevice = null);
                _confirmDeleteDevice(d);
              },
            ),
          ),
      ],
    );
  }

  // --- Desktop Full Screen Layout (> 1200px) ---
  Widget _buildDesktopLayout(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Bar & KPIs Bar Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Device Management & Control',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Register, organize, monitor and control all campus devices from a single platform',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DeviceManagementKpisBar(kpis: state.kpis),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Main Body: Left Sub-Nav + Dynamic Center View
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Sub-Nav Panel (~230px)
              SizedBox(
                width: 230,
                child: DeviceManagementLeftPanel(
                  selectedIndex: state.selectedSubNavIndex,
                  onItemSelected: notifier.setSubNavIndex,
                  onAddDevice: _openAddDeviceWizard,
                ),
              ),
              const SizedBox(width: 12),

              // Center Content Switched dynamically based on selectedSubNavIndex
              Expanded(
                child: _buildCenterContent(state, notifier, isDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Dynamic Central Content Switcher ---
  Widget _buildCenterContent(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    switch (state.selectedSubNavIndex) {
      case 0:
        return _buildOverviewDashboard(state, notifier, isDark);
      case 1:
        return DeviceRegistrySubview(
          onBackToDashboard: () => notifier.setSubNavIndex(0),
        );
      case 2:
        return const DeviceTypesProfilesSubview();
      case 3:
        return const DeviceGroupsSubview();
      case 4:
        return const DeviceLocationsMappingSubview();
      case 5:
        return const DeviceLiveControlSubview();
      case 6:
        return const DeviceBulkOperationsSubview();
      case 7:
        return DeviceAutomationsSubview(
          automations: state.automationsList,
          onBackToDashboard: () => notifier.setSubNavIndex(0),
          onToggleAutomation: notifier.toggleAutomation,
          onCreateRule: (data) => notifier.createAutomationRule(data),
          onUpdateRule: (id, data) => notifier.updateAutomationRule(id, data),
          onDeleteRule: (id) => notifier.deleteAutomationRule(id),
          onDuplicateRule: (id) => notifier.duplicateAutomationRule(id),
          onTestRule: (data) => notifier.testAutomationRule(data),
          onRunCron: notifier.runAutomationCron,
        );
      case 8:
        return DeviceSchedulesSubview(
          schedules: state.schedulesList,
          onBackToDashboard: () => notifier.setSubNavIndex(0),
          onToggleSchedule: notifier.toggleSchedule,
        );
      case 9:
        return DeviceScenesPresetsSubview(
          onBackToDashboard: () => notifier.setSubNavIndex(0),
          onExecuteScene: notifier.executeScene,
        );
      case 10:
        return DeviceEnergyUsageSubview(
          onBackToDashboard: () => notifier.setSubNavIndex(0),
        );
      case 11:
        return DeviceHealthDiagnosticsSubview(
          onBackToDashboard: () => notifier.setSubNavIndex(0),
        );
      case 12:
        return DeviceIntegrationsGatewaysSubview(
          onBackToDashboard: () => notifier.setSubNavIndex(0),
        );
      case 13:
        return DeviceAccessPermissionsSubview(
          onBackToDashboard: () => notifier.setSubNavIndex(0),
        );
      case 14:
        return DeviceAuditLogsSubview(
          logs: state.auditLogsList,
          onBackToDashboard: () => notifier.setSubNavIndex(0),
        );
      case 15:
        return DeviceImportExportSubview(
          onBackToDashboard: () => notifier.setSubNavIndex(0),
        );
      default:
        return _buildOverviewDashboard(state, notifier, isDark);
    }
  }

  // --- Sub-View 0: Overview Dashboard (Matching Screenshot Pixel-Perfect) ---
  Widget _buildOverviewDashboard(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upper Row: Overview Map + Devices By Type Donut + Quick Controls (Height ~240px)
          SizedBox(
            height: 240,
            child: Row(
              children: [
                // Campus Overview Map (Isometric)
                Expanded(
                  flex: 22,
                  child: DeviceOverviewCard(
                    buildings: state.buildingsBreakdown,
                    selectedCampusBuilding: state.selectedCampusBuildingCode,
                    onBuildingChanged: notifier.setSelectedCampusBuilding,
                  ),
                ),
                const SizedBox(width: 10),

                // Devices by Type Donut
                Expanded(
                  flex: 15,
                  child: DevicesByTypeDonutCard(
                    types: state.devicesByType,
                    totalDevices: state.kpis.totalDevices,
                    selectedType: state.filterType,
                    onTypeSelected: notifier.setFilterType,
                  ),
                ),
                const SizedBox(width: 10),

                // Quick Controls (Entire Campus)
                Expanded(
                  flex: 14,
                  child: DeviceQuickControlsCard(
                    onActionTriggered: (action) => _handleQuickControlAction(action, state, notifier),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Center Row: Device Control Table (Live) + Location Explorer (Height ~380px)
          SizedBox(
            height: 380,
            child: Row(
              children: [
                // Device Live Control Table
                Expanded(
                  flex: 32,
                  child: _buildTable(state, notifier),
                ),
                const SizedBox(width: 10),

                // Location Explorer Tree
                Expanded(
                  flex: 13,
                  child: _buildLocationExplorer(state, notifier),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Bottom Row: 4 Cards (Energy Usage + Active Automations + Scenes + Alerts) (Height ~210px)
          SizedBox(
            height: 210,
            child: Row(
              children: [
                // 1. Energy & Usage (Dual axis chart)
                Expanded(
                  flex: 14,
                  child: DeviceEnergyUsageCard(
                    data: state.energyData,
                    currentPeriod: state.energyTimePeriod,
                    onPeriodChanged: notifier.setEnergyTimePeriod,
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Active Automations (128)
                Expanded(
                  flex: 13,
                  child: DeviceActiveAutomationsCard(
                    automations: state.activeAutomations,
                    onViewAll: () => notifier.setSubNavIndex(7),
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Scenes & Presets
                Expanded(
                  flex: 12,
                  child: DeviceScenesPresetsCard(
                    scenes: state.scenes,
                    onSelectScene: notifier.executeScene,
                    onCreateCustomScene: _openCreateSceneDialog,
                    onManageScenes: () => notifier.setSubNavIndex(9),
                  ),
                ),
                const SizedBox(width: 10),

                // 4. Recent Alerts & Events
                Expanded(
                  flex: 11,
                  child: DeviceRecentAlertsCard(
                    alerts: state.recentAlerts,
                    onViewAll: () => notifier.setSubNavIndex(11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }










  // --- Tablet Layout (800 - 1200px) ---
  Widget _buildTabletLayout(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    if (state.selectedSubNavIndex > 0) {
      return _buildCenterContent(state, notifier, isDark);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Device Management & Control',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          DeviceManagementKpisBar(kpis: state.kpis),
          const SizedBox(height: 14),

          // Upper Row
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DeviceOverviewCard(
                    buildings: state.buildingsBreakdown,
                    selectedCampusBuilding: state.selectedCampusBuildingCode,
                    onBuildingChanged: notifier.setSelectedCampusBuilding,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DevicesByTypeDonutCard(
                    types: state.devicesByType,
                    totalDevices: state.kpis.totalDevices,
                    selectedType: state.filterType,
                    onTypeSelected: notifier.setFilterType,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick Controls Tile
          SizedBox(
            height: 160,
            child: DeviceQuickControlsCard(
              onActionTriggered: (action) => _handleQuickControlAction(action, state, notifier),
            ),
          ),
          const SizedBox(height: 14),

          // Device Table
          SizedBox(
            height: 380,
            child: _buildTable(state, notifier),
          ),
          const SizedBox(height: 14),

          // Location Explorer
          SizedBox(
            height: 260,
            child: _buildLocationExplorer(state, notifier),
          ),
          const SizedBox(height: 14),

          // Bottom Cards
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: DeviceEnergyUsageCard(
                    data: state.energyData,
                    currentPeriod: state.energyTimePeriod,
                    onPeriodChanged: notifier.setEnergyTimePeriod,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DeviceActiveAutomationsCard(
                    automations: state.activeAutomations,
                    onViewAll: () => notifier.setSubNavIndex(7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: DeviceScenesPresetsCard(
                    scenes: state.scenes,
                    onSelectScene: notifier.executeScene,
                    onCreateCustomScene: _openCreateSceneDialog,
                    onManageScenes: () => notifier.setSubNavIndex(9),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DeviceRecentAlertsCard(
                    alerts: state.recentAlerts,
                    onViewAll: () => notifier.setSubNavIndex(11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- Mobile Single-Column Layout (< 800px) ---
  Widget _buildMobileLayout(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    if (state.selectedSubNavIndex > 0) {
      return _buildCenterContent(state, notifier, isDark);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Device Management & Control',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          DeviceManagementKpisBar(kpis: state.kpis),
          const SizedBox(height: 12),

          // Action Button on Mobile
          ElevatedButton.icon(
            onPressed: _openAddDeviceWizard,
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('Add New Device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Overview Card
          SizedBox(
            height: 220,
            child: DeviceOverviewCard(
              buildings: state.buildingsBreakdown,
              selectedCampusBuilding: state.selectedCampusBuildingCode,
              onBuildingChanged: notifier.setSelectedCampusBuilding,
            ),
          ),
          const SizedBox(height: 12),

          // Devices by Type
          SizedBox(
            height: 200,
            child: DevicesByTypeDonutCard(
              types: state.devicesByType,
              totalDevices: state.kpis.totalDevices,
              selectedType: state.filterType,
              onTypeSelected: notifier.setFilterType,
            ),
          ),
          const SizedBox(height: 12),

          // Quick Controls
          SizedBox(
            height: 180,
            child: DeviceQuickControlsCard(
              onActionTriggered: (action) => _handleQuickControlAction(action, state, notifier),
            ),
          ),
          const SizedBox(height: 12),

          // Table
          SizedBox(
            height: 380,
            child: _buildTable(state, notifier),
          ),
          const SizedBox(height: 12),

          // Location Explorer
          SizedBox(
            height: 240,
            child: _buildLocationExplorer(state, notifier),
          ),
          const SizedBox(height: 12),

          // Energy Usage
          SizedBox(
            height: 200,
            child: DeviceEnergyUsageCard(
              data: state.energyData,
              currentPeriod: state.energyTimePeriod,
              onPeriodChanged: notifier.setEnergyTimePeriod,
            ),
          ),
          const SizedBox(height: 12),

          // Active Automations
          SizedBox(
            height: 200,
            child: DeviceActiveAutomationsCard(
              automations: state.activeAutomations,
              onViewAll: () => notifier.setSubNavIndex(7),
            ),
          ),
          const SizedBox(height: 12),

          // Scenes & Presets
          SizedBox(
            height: 180,
            child: DeviceScenesPresetsCard(
              scenes: state.scenes,
              onSelectScene: notifier.executeScene,
              onCreateCustomScene: _openCreateSceneDialog,
              onManageScenes: () => notifier.setSubNavIndex(9),
            ),
          ),
          const SizedBox(height: 12),

          // Recent Alerts
          SizedBox(
            height: 200,
            child: DeviceRecentAlertsCard(
              alerts: state.recentAlerts,
              onViewAll: () => notifier.setSubNavIndex(11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
