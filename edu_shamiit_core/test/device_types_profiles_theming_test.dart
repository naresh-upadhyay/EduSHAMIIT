import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_types_profiles_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/create_edit_device_profile_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/deploy_device_profile_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/create_edit_device_type_wizard_dialog.dart';

class FakeDeviceManagementNotifier extends DeviceManagementNotifier {
  FakeDeviceManagementNotifier(DeviceManagementState initialState)
      : super(DeviceManagementApiService.instance) {
    state = initialState;
  }

  @override
  Future<void> loadTypesAndProfilesData() async {
    // Keep test state intact without network calls
  }

  @override
  Future<void> loadDeviceProfiles({String? deviceTypeId}) async {}

  @override
  Future<void> loadCapabilitiesLibrary() async {}
}

void main() {
  const sampleProfile = DeviceProfileItem(
    id: 'prof-001',
    deviceTypeId: 'dt-001',
    deviceTypeName: '4K PTZ Surveillance Camera',
    name: 'Classroom Standard Surveillance Profile',
    code: 'CAM_CLASSROOM_STD',
    profileType: 'custom',
    manufacturer: 'Hikvision',
    model: 'DS-2CD2143G2-I',
    description: 'High-definition 1080p surveillance streaming with automated sleep during exams',
    version: '1.2.0',
    status: 'active',
    isDefault: true,
    usageCount: 42,
  );

  const sampleType = DeviceTypeDetailItem(
    id: 'dt-001',
    name: '4K PTZ Surveillance Camera',
    code: 'CAM_PTZ_4K',
    categoryName: 'Security',
    systemCategory: 'Security & Surveillance',
    description: 'Ultra high-definition pan-tilt-zoom optical camera for campus corridors and perimeters',
    icon: 'videocam',
    color: '#DC2626',
    protocol: 'ONVIF',
    supportedProtocols: ['ONVIF', 'RTSP', 'MQTT'],
    manufacturer: 'Hikvision',
    supportedModels: ['DS-2CD2143G2-I', 'DS-2CD2087G2-LU'],
    tags: ['Indoor', 'CCTV', 'Exam Surveillance'],
    defaultCapabilities: ['Live View', 'PTZ Control', 'Recording'],
    mappedDevicesCount: 42,
    profilesCount: 2,
    isActive: true,
    status: 'Active',
    profiles: [sampleProfile],
  );

  const sampleCapTemplate = CapabilityTemplateItem(
    id: 'cap-001',
    name: 'PTZ Control Joystick',
    code: 'ptz_control',
    type: 'ptz',
    dataType: 'object',
    category: 'Security',
    icon: 'control_camera',
    description: 'Real-time pan, tilt, and continuous optical zoom manipulation for surveillance units',
  );

  const sampleScene = DeviceSceneItem(
    id: 'sc-001',
    sceneCode: 'SCENE_CLASS_START',
    name: 'Class Start',
    code: 'CLASS_START',
    category: 'Classroom',
    sceneType: 'scene',
    targetType: 'classroom',
    targetName: 'All Classrooms',
    targetCount: 48,
    locationScope: 'All Buildings',
    tags: ['Automation', 'Morning Routine'],
    description: 'Prepare classroom for class (lights, AC, projector)',
    icon: 'school',
    colorHex: '#2563EB',
  );

  final testState = DeviceManagementState(
    isLoading: false,
    isTypesLoading: false,
    typesProfilesKpis: const DeviceTypesProfilesKpis(
      totalDeviceTypes: 28,
      activeProfiles: 82,
      defaultProfiles: 25,
      customProfiles: 57,
      mappedDevices: 223,
      complianceRate: 95.4,
    ),
    deviceTypesList: const [sampleType],
    totalDeviceTypes: 1,
    selectedDeviceTypeId: 'dt-001',
    selectedDeviceTypeDetail: sampleType,
    deviceProfilesList: const [sampleProfile],
    capabilitiesLibrary: const [sampleCapTemplate],
    scenes: const [sampleScene],
    typesActiveSubTab: 'Device Types (28)',
  );

  Widget createTestWidget({
    required Widget child,
    required ThemeMode themeMode,
    DeviceManagementState? customState,
  }) {
    final state = customState ?? testState;
    return ProviderScope(
      overrides: [
        deviceManagementProvider.overrideWith((ref) => FakeDeviceManagementNotifier(state)),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB), brightness: Brightness.light),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB), brightness: Brightness.dark),
        ),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Device Types & Profiles Theming Tests', () {
    testWidgets('DeviceTypesProfilesSubview renders cleanly in Dark Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        createTestWidget(
          child: const DeviceTypesProfilesSubview(),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify KPI items rendered
      expect(find.text('Total Device Types'), findsOneWidget);
      expect(find.text('Active Profiles'), findsOneWidget);
      expect(find.text('Default Profiles'), findsOneWidget);
      expect(find.text('Custom Profiles'), findsOneWidget);
      expect(find.text('Mapped Devices'), findsWidgets);
      expect(find.text('Compliance'), findsOneWidget);

      // Verify Sub-Tabs rendered
      expect(find.textContaining('Device Types'), findsWidgets);
      expect(find.textContaining('Control Profiles'), findsWidgets);
      expect(find.text('Capability Templates'), findsOneWidget);
      expect(find.text('Presets & Scenes'), findsOneWidget);

      // Verify Selected Device Type details rendered
      expect(find.text('4K PTZ Surveillance Camera'), findsWidgets);
      expect(find.text('System Category'), findsOneWidget);
      expect(find.text('Capabilities'), findsOneWidget);
    });

    testWidgets('DeviceTypesProfilesSubview renders cleanly in Light Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        createTestWidget(
          child: const DeviceTypesProfilesSubview(),
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify Header & Search rendered
      expect(find.text('Device Types & Profiles'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('Control Profiles (Tab 2) renders cleanly in Dark Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      final stateWithTab2 = testState.copyWith(typesActiveSubTab: 'Control Profiles (82)');

      await tester.pumpWidget(
        createTestWidget(
          child: const DeviceTypesProfilesSubview(),
          themeMode: ThemeMode.dark,
          customState: stateWithTab2,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('All Control Profiles (1)'), findsOneWidget);
      expect(find.text('Classroom Standard Surveillance Profile'), findsOneWidget);
      expect(find.text('Deploy'), findsOneWidget);
    });

    testWidgets('Capability Templates (Tab 3) renders cleanly in Dark Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      final stateWithTab3 = testState.copyWith(typesActiveSubTab: 'Capability Templates');

      await tester.pumpWidget(
        createTestWidget(
          child: const DeviceTypesProfilesSubview(),
          themeMode: ThemeMode.dark,
          customState: stateWithTab3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Capability Templates Catalog'), findsOneWidget);
      expect(find.text('PTZ Control Joystick'), findsOneWidget);
    });

    testWidgets('Presets & Scenes (Tab 4) renders cleanly in Dark Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      final stateWithTab4 = testState.copyWith(typesActiveSubTab: 'Presets & Scenes');

      await tester.pumpWidget(
        createTestWidget(
          child: const DeviceTypesProfilesSubview(),
          themeMode: ThemeMode.dark,
          customState: stateWithTab4,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Configured Presets & Operational Scenes'), findsOneWidget);
      expect(find.text('Class Start'), findsOneWidget);
    });

    testWidgets('CreateEditDeviceProfileDialog renders cleanly in Dark Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));

      await tester.pumpWidget(
        createTestWidget(
          child: CreateEditDeviceProfileDialog(
            initialProfile: sampleProfile,
            availableDeviceTypes: const [sampleType],
            onSave: (_) async => true,
          ),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Edit Control Profile'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('DeployDeviceProfileDialog renders cleanly in Dark Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));

      await tester.pumpWidget(
        createTestWidget(
          child: DeployDeviceProfileDialog(
            profile: sampleProfile,
            deviceType: sampleType,
            onDeploy: (_) async => true,
          ),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Deploy Control Profile'), findsOneWidget);
      expect(find.text('Deployment Scope'), findsOneWidget);
      expect(find.text('Audit Notes'), findsOneWidget);
      expect(find.text('Confirm & Deploy'), findsOneWidget);
    });

    testWidgets('CreateEditDeviceTypeWizardDialog renders cleanly in Dark Theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        createTestWidget(
          child: CreateEditDeviceTypeWizardDialog(
            initialType: sampleType,
            onSave: (_) async => true,
          ),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Device Type: 4K PTZ Surveillance Camera'), findsOneWidget);
      expect(find.text('1. Basic Specifications'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });
}
