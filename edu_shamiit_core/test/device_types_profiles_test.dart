import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_types_profiles_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/create_edit_device_type_wizard_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/create_edit_device_profile_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/deploy_device_profile_dialog.dart';

class TestDeviceManagementNotifier extends DeviceManagementNotifier {
  TestDeviceManagementNotifier() : super(DeviceManagementApiService.instance);

  @override
  Future<void> loadTypesAndProfilesData() async {}

  @override
  Future<void> loadDeviceProfiles({String? deviceTypeId}) async {}

  @override
  Future<void> loadCapabilitiesLibrary() async {}
}

void main() {
  group('Device Types & Profiles - Models Tests', () {
    test(
        'DeviceTypesProfilesKpis JSON deserialization matching screenshot metrics',
        () {
      final json = {
        'total_device_types': 24,
        'active_profiles': 76,
        'default_profiles': 24,
        'custom_profiles': 52,
        'mapped_devices': 8742,
        'compliance_rate': 95.4,
      };

      final kpis = DeviceTypesProfilesKpis.fromJson(json);
      expect(kpis.totalDeviceTypes, 24);
      expect(kpis.activeProfiles, 76);
      expect(kpis.defaultProfiles, 24);
      expect(kpis.customProfiles, 52);
      expect(kpis.mappedDevices, 8742);
      expect(kpis.complianceRate, 95.4);
    });

    test('DeviceTypeDetailItem and DeviceProfileItem deserialization', () {
      final json = {
        'id': 'cctv-1234',
        'name': 'CCTV',
        'code': 'cctv',
        'category_name': 'Security',
        'category_code': 'security',
        'system_category': 'Security & Surveillance',
        'description': 'IP/Network surveillance cameras',
        'icon': 'videocam',
        'color': '#DC2626',
        'protocol': 'ONVIF',
        'supported_protocols': ['ONVIF', 'RTSP', 'HTTP(S)'],
        'default_capabilities': [
          'Live View',
          'PTZ Control',
          'Recording',
          'Snapshot',
          'Motion Alert',
          'Stream Share'
        ],
        'mapped_devices_count': 1284,
        'profiles_count': 6,
        'is_active': true,
        'status': 'Active',
        'updated_at': '12 Jan 2025, 10:24 AM',
        'profiles': [
          {
            'id': 'prof-1',
            'device_type_id': 'cctv-1234',
            'name': 'Default CCTV Profile',
            'code': 'def_cctv',
            'profile_type': 'default',
            'version': '1.0.0',
            'status': 'active',
            'is_default': true,
            'usage_count': 842,
          },
          {
            'id': 'prof-2',
            'device_type_id': 'cctv-1234',
            'name': 'PTZ Control Profile',
            'code': 'ptz_cctv',
            'profile_type': 'custom',
            'version': '1.0.0',
            'status': 'active',
            'is_default': false,
            'usage_count': 218,
          },
        ],
      };

      final dt = DeviceTypeDetailItem.fromJson(json);
      expect(dt.name, 'CCTV');
      expect(dt.categoryName, 'Security');
      expect(dt.mappedDevicesCount, 1284);
      expect(dt.profilesCount, 6);
      expect(dt.defaultCapabilities.length, 6);
      expect(dt.profiles.length, 2);
      expect(dt.profiles.first.name, 'Default CCTV Profile');
      expect(dt.profiles.first.isDefault, isTrue);
      expect(dt.profiles.first.usageCount, 842);
      expect(dt.profiles[1].profileType, 'custom');
      expect(dt.profiles[1].usageCount, 218);
    });

    test('CapabilityTemplateItem deserialization', () {
      final json = {
        'id': 'power',
        'name': 'Power Control',
        'code': 'power_state',
        'type': 'switch',
        'data_type': 'boolean',
        'category': 'Basic',
        'icon': 'power_settings_new',
        'description': 'Turns hardware on or off.',
        'default_value': false,
      };

      final cap = CapabilityTemplateItem.fromJson(json);
      expect(cap.id, 'power');
      expect(cap.name, 'Power Control');
      expect(cap.type, 'switch');
      expect(cap.category, 'Basic');
    });
  });

  group('Device Types & Profiles - UI Widgets and Layout Tests', () {
    testWidgets(
        'Renders KPI Cards, Sub-Tabs, Search and Controls with 0 overflows',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      const cctvType = DeviceTypeDetailItem(
        id: 'cctv-1',
        name: 'CCTV',
        code: 'cctv',
        categoryName: 'Security',
        systemCategory: 'Security & Surveillance',
        description: 'IP/Network surveillance cameras',
        mappedDevicesCount: 1284,
        profilesCount: 6,
        defaultCapabilities: [
          'Live View',
          'PTZ Control',
          'Recording',
          'Snapshot',
          'Motion Alert',
          'Stream Share'
        ],
        profiles: [
          DeviceProfileItem(
              id: 'p1',
              deviceTypeId: 'cctv-1',
              name: 'Default CCTV Profile',
              code: 'def_cctv',
              isDefault: true,
              usageCount: 842),
          DeviceProfileItem(
              id: 'p2',
              deviceTypeId: 'cctv-1',
              name: 'PTZ Control Profile',
              code: 'ptz_cctv',
              profileType: 'custom',
              usageCount: 218),
        ],
      );

      const projectorType = DeviceTypeDetailItem(
        id: 'proj-1',
        name: 'Projector',
        code: 'projector',
        categoryName: 'AV & Display',
        systemCategory: 'Audio Visual & Multimedia',
        description: 'Classroom & auditorium projectors',
        mappedDevicesCount: 320,
        profilesCount: 4,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) {
              final notifier = TestDeviceManagementNotifier();
              notifier.state = notifier.state.copyWith(
                typesProfilesKpis: const DeviceTypesProfilesKpis(
                  totalDeviceTypes: 24,
                  activeProfiles: 76,
                  defaultProfiles: 24,
                  customProfiles: 52,
                  mappedDevices: 8742,
                  complianceRate: 95.4,
                ),
                deviceTypesList: [cctvType, projectorType],
                totalDeviceTypes: 24,
                selectedDeviceTypeId: 'cctv-1',
                selectedDeviceTypeDetail: cctvType,
                typesActiveSubTab: 'Device Types (24)',
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceTypesProfilesSubview(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify KPIs Bar
      expect(find.text('Total Device Types'), findsOneWidget);
      expect(find.text('24'),
          findsNWidgets(2)); // Total Device Types: 24 & Default Profiles: 24
      expect(find.text('Active Profiles'), findsOneWidget);
      expect(find.text('76'), findsOneWidget);
      expect(find.text('Default Profiles'), findsOneWidget);
      expect(find.text('Custom Profiles'), findsOneWidget);
      expect(find.text('52'), findsOneWidget);
      expect(find.text('Mapped Devices'),
          findsNWidgets(2)); // KPI card and table column
      expect(find.text('8,742'), findsOneWidget);
      expect(find.text('Compliance'), findsOneWidget);
      expect(find.text('95.4%'), findsOneWidget);

      // Verify Section Header & Actions
      expect(find.text('Device Types & Profiles'), findsOneWidget);
      expect(find.text('Add Device Type'), findsOneWidget);

      // Verify Sub-Tabs
      expect(find.text('Device Types (24)'), findsOneWidget);
      expect(find.text('Control Profiles (76)'), findsOneWidget);
      expect(find.text('Capability Templates'), findsOneWidget);
      expect(find.text('Presets & Scenes'), findsOneWidget);

      // Verify Data Table columns and content
      expect(
          find.text('CCTV'), findsNWidgets(2)); // In table & in right inspector
      expect(find.text('Projector'), findsOneWidget);
      expect(find.text('Security'), findsNWidgets(2));
      expect(find.text('1,284'), findsNWidgets(2)); // Table & Inspector

      // Verify Right Inspector Details
      expect(find.text('Device Type Details'), findsOneWidget);
      expect(find.text('Control Profiles (2)'), findsOneWidget);
      expect(find.text('Default CCTV Profile'), findsOneWidget);
      expect(find.text('PTZ Control Profile'), findsOneWidget);
      expect(find.text('Capability Configuration'), findsOneWidget);
      expect(find.text('Default Settings'), findsOneWidget);
      expect(find.text('Assigned Devices (1,284)'), findsOneWidget);

      // Check zero render overflows
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Responsiveness Test on Mobile Screen (360x640) with 0 overflows',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) {
              final notifier = TestDeviceManagementNotifier();
              notifier.state = notifier.state.copyWith(
                typesProfilesKpis: const DeviceTypesProfilesKpis(
                  totalDeviceTypes: 24,
                  activeProfiles: 76,
                  defaultProfiles: 24,
                  customProfiles: 52,
                  mappedDevices: 8742,
                  complianceRate: 95.4,
                ),
                totalDeviceTypes: 24,
                typesActiveSubTab: 'Device Types (24)',
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceTypesProfilesSubview(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Device Types & Profiles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Responsiveness Test on Laptop Screen (1280x800) with 0 overflows',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) {
              final notifier = TestDeviceManagementNotifier();
              notifier.state = notifier.state.copyWith(
                typesProfilesKpis: const DeviceTypesProfilesKpis(
                  totalDeviceTypes: 24,
                  activeProfiles: 76,
                  defaultProfiles: 24,
                  customProfiles: 52,
                  mappedDevices: 8742,
                  complianceRate: 95.4,
                ),
                totalDeviceTypes: 24,
                typesActiveSubTab: 'Device Types (24)',
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceTypesProfilesSubview(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Device Types & Profiles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Device Types & Profiles - Dialogs Tests', () {
    testWidgets('CreateEditDeviceTypeWizardDialog renders and navigates steps',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateEditDeviceTypeWizardDialog(
              onSave: (payload) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add New Device Type'), findsOneWidget);
      expect(find.text('1. Basic Specifications'), findsOneWidget);
      expect(find.text('2. Capability Builder'), findsOneWidget);
      expect(find.text('3. Review & Summary'), findsOneWidget);

      // Fill in Name and proceed
      await tester.enterText(
          find.byType(TextFormField).first, 'Smart Whiteboard');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Select Hardware Capabilities for this Device Type'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CreateEditDeviceProfileDialog renders fields', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 750));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateEditDeviceProfileDialog(
              defaultDeviceTypeName: 'CCTV',
              onSave: (data) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add New Control Profile'), findsOneWidget);
      expect(find.text('Target Device Type: CCTV'), findsOneWidget);
      expect(find.text('Default Settings & Safety Limits'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'DeployDeviceProfileDialog renders scopes and deploy confirmation',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 600));

      const profile = DeviceProfileItem(
        id: 'p-cctv',
        deviceTypeId: 'dt-cctv',
        deviceTypeName: 'CCTV',
        name: 'High Security (24x7)',
        code: 'high_sec_cctv',
        usageCount: 124,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeployDeviceProfileDialog(
              profile: profile,
              onDeploy: (data) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Deploy Control Profile'), findsOneWidget);
      expect(find.text('High Security (24x7)'), findsOneWidget);
      expect(find.text('Confirm & Deploy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
