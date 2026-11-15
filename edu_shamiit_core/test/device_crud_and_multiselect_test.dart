import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_types_profiles_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_groups_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/create_edit_device_type_wizard_dialog.dart';

class MockDeviceManagementNotifier extends DeviceManagementNotifier {
  MockDeviceManagementNotifier() : super(DeviceManagementApiService.instance);

  @override
  Future<void> loadTypesAndProfilesData() async {}

  @override
  Future<void> loadGroups() async {}

  @override
  Future<void> loadOverview() async {}
}

void main() {
  group('Device Management - CRUD & Multiselect Edge Case Tests', () {
    testWidgets('Create Device Type "KING" completes step 3 without unmounted validate crash', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? savedPayload;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: CreateEditDeviceTypeWizardDialog(
              onSave: (payload) async {
                savedPayload = payload;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Basic Specifications
      expect(find.text('1. Basic Specifications'), findsOneWidget);
      expect(find.text('Device Type Name *'), findsOneWidget);

      // Enter "KING" into name field
      final nameFields = find.byType(TextFormField);
      await tester.enterText(nameFields.first, 'KING');
      await tester.pumpAndSettle();

      // Click "Continue" to move to Step 2
      final continueBtn = find.widgetWithText(ElevatedButton, 'Continue');
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 2: Capability Builder
      expect(find.text('2. Capability Builder'), findsOneWidget);
      expect(find.text('Select Hardware Capabilities for this Device Type'), findsOneWidget);

      // Click "Continue" to move to Step 3
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 3: Review & Summary
      expect(find.text('3. Review & Summary'), findsOneWidget);
      expect(find.text('Review Device Type Configuration'), findsOneWidget);
      expect(find.text('KING'), findsOneWidget);

      // Verify "Create Device Type" button is rendered
      final createBtn = find.widgetWithText(ElevatedButton, 'Create Device Type');
      expect(createBtn, findsOneWidget);

      // Tap "Create Device Type"
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Expect onSave was successfully called with "KING" and without null exception crash!
      expect(savedPayload, isNotNull);
      expect(savedPayload!['name'], 'KING');
      expect(savedPayload!['code'], 'king');
      expect(savedPayload!['is_active'], true);
    });

    testWidgets('Device Types Table: Exactly ONE checkbox column, NO double checkboxes', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockTypes = [
        const DeviceTypeDetailItem(
          id: 'type-1',
          name: 'Projector',
          code: 'projector',
          categoryName: 'AV & Display',
          systemCategory: 'AV & Display',
          description: 'Classroom & auditorium projectors',
          icon: 'videocam',
          color: '#2563EB',
          protocol: 'MQTT',
          supportedProtocols: ['MQTT'],
          defaultCapabilities: ['Power', 'Volume'],
          mappedDevicesCount: 320,
          profilesCount: 4,
          isActive: true,
          status: 'Active',
          updatedAt: '12 Jan 2025',
          profiles: [],
        ),
        const DeviceTypeDetailItem(
          id: 'type-2',
          name: 'CCTV Camera',
          code: 'cctv_camera',
          categoryName: 'Security',
          systemCategory: 'Security & Surveillance',
          description: 'High-definition cameras',
          icon: 'videocam',
          color: '#DC2626',
          protocol: 'ONVIF',
          supportedProtocols: ['ONVIF'],
          defaultCapabilities: ['Live View'],
          mappedDevicesCount: 1284,
          profilesCount: 6,
          isActive: true,
          status: 'Active',
          updatedAt: '12 Jan 2025',
          profiles: [],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) {
              final n = MockDeviceManagementNotifier();
              n.state = n.state.copyWith(
                deviceTypesList: mockTypes,
                selectedDeviceTypeId: 'type-1',
                typesActiveSubTab: 'Device Types (24)',
              );
              return n;
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

      // DataTable check
      final dataTableFinder = find.byType(DataTable);
      expect(dataTableFinder, findsOneWidget);

      final dataTable = tester.widget<DataTable>(dataTableFinder);
      // Verify showCheckboxColumn is explicitly false so Flutter does not generate redundant checkboxes
      expect(dataTable.showCheckboxColumn, isFalse);

      // Verify checkboxes: 1 header checkbox + 2 row checkboxes = exactly 3 checkboxes in the table
      final checkboxes = find.descendant(of: dataTableFinder, matching: find.byType(Checkbox));
      expect(checkboxes, findsNWidgets(3));

      // Initially no rows selected, bulk actions bar is hidden
      expect(find.textContaining('selected'), findsNothing);

      // Select first row checkbox
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      // Bulk action bar must now appear with "1 of 2 selected"
      expect(find.text('1 of 2 selected'), findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap "Deselect All"
      final deselectBtn = find.text('Deselect All');
      expect(deselectBtn, findsOneWidget);
      await tester.ensureVisible(deselectBtn);
      await tester.pumpAndSettle();
      await tester.tap(deselectBtn);
      await tester.pumpAndSettle();

      // Bulk actions bar is hidden again
      expect(find.text('1 of 2 selected'), findsNothing);
    });

    testWidgets('Device Groups Table: Single checkbox column and working multiselect', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockGroups = [
        const DeviceGroupItem(
          id: 'grp-1',
          name: 'Academic Block A Lights',
          code: 'GRP-LGT-A',
          groupType: 'room',
          locationScope: 'Academic Block > Floor 1',
          deviceCount: 42,
          profileName: 'Default Profile',
          status: 'Active',
          onlineCount: 40,
          offlineCount: 2,
          schedulesCount: 2,
          automationsCount: 1,
          scenesCount: 1,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) {
              final n = MockDeviceManagementNotifier();
              n.state = n.state.copyWith(
                groupsList: mockGroups,
                selectedGroupId: 'grp-1',
              );
              return n;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceGroupsSubview(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify DataTable has showCheckboxColumn: false
      final dataTableFinder = find.byType(DataTable);
      expect(dataTableFinder, findsOneWidget);

      final dataTable = tester.widget<DataTable>(dataTableFinder);
      expect(dataTable.showCheckboxColumn, isFalse);

      // Exactly 2 checkboxes (1 header + 1 row)
      final checkboxes = find.descendant(of: dataTableFinder, matching: find.byType(Checkbox));
      expect(checkboxes, findsNWidgets(2));

      // Select group row
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      // Bulk actions bar appears
      expect(find.text('1 of 1 groups selected'), findsOneWidget);

      // Tap "Deselect All"
      final deselectBtn = find.text('Deselect All');
      expect(deselectBtn, findsOneWidget);
      await tester.ensureVisible(deselectBtn);
      await tester.pumpAndSettle();
      await tester.tap(deselectBtn);
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 groups selected'), findsNothing);
    });

    testWidgets('Dynamic Theme Switching: Wizard adapts to Dark Mode theme', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1)),
          ),
          home: Scaffold(
            body: CreateEditDeviceTypeWizardDialog(
              onSave: (_) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dialog renders cleanly in dark theme
      expect(find.text('Add New Device Type'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);

      // Verify theme primary color is used on buttons
      final continueBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue'));
      expect(continueBtn.style?.backgroundColor?.resolve({}), const Color(0xFF6366F1));
    });
  });
}
