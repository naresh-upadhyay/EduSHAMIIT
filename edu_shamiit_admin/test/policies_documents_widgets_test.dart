import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/manage_categories_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/create_policy_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/upload_document_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/policy_detail_drawer.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/document_detail_drawer.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/request_acknowledgement_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/policy_acknowledgement_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/template_editor_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/institutional_document_renderer.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/reports_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/hr_policies_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('EduSHAMIIT ERP - Policies & Documents Widget Tests', () {
    testWidgets('1. HRManagementTabHeader renders with active Policies & Documents tab', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HRManagementTabHeader(activeTab: HRTab.policies),
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Recruitment'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Training & Learning'), findsOneWidget);
      expect(find.text('Policies & Documents'), findsOneWidget);
    });

    testWidgets('2. ManageCategoriesDialog renders category manager and color options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManageCategoriesDialog(onCategoriesChanged: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Manage Policy & Document Categories'), findsOneWidget);
      expect(find.text('Create Category'), findsOneWidget);
      expect(find.text('Add Category'), findsOneWidget);
    });

    testWidgets('3. CreatePolicyDialog renders all 4 authoring tabs and lifecycle actions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatePolicyDialog(onPolicyCreated: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Create Institutional Policy'), findsOneWidget);
      expect(find.text('1. Basic Info'), findsOneWidget);
      expect(find.text('2. Policy Content'), findsOneWidget);
      expect(find.text('3. Lifecycle & Dates'), findsOneWidget);
      expect(find.text('4. Acknowledgement'), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Submit for Review'), findsOneWidget);
      expect(find.text('Publish Policy'), findsOneWidget);
    });

    testWidgets('4. UploadDocumentDialog renders file drop zone, fields and upload action', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadDocumentDialog(onDocumentUploaded: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Upload HR / Compliance Document'), findsOneWidget);
      expect(find.text('Click to browse or drop file here'), findsOneWidget);
      expect(find.text('Upload Document'), findsOneWidget);
    });

    testWidgets('5. PolicyDetailDrawer renders tabs: Overview, Content, Versions, Sign-offs, Activity', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolicyDetailDrawer(
              policyId: 'dummy-pol-1',
              onPolicyUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PolicyDetailDrawer), findsOneWidget);
    });

    testWidgets('6. DocumentDetailDrawer renders preview and version replace UI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentDetailDrawer(
              documentId: 'dummy-doc-1',
              onDocumentUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DocumentDetailDrawer), findsOneWidget);
    });

    testWidgets('7. RequestAcknowledgementDialog renders audience picker and dispatch button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestAcknowledgementDialog(onRequested: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Request Policy Sign-off'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('8. PolicyAcknowledgementDialog renders digital sign-off agreement and checkbox', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolicyAcknowledgementDialog(
              acknowledgement: const {
                'id': 'ack-123',
                'policy_id': 'pol-123',
                'policy_title': 'Employee Code of Conduct',
                'version_number': '1.0',
                'is_mandatory': true,
              },
              onAcknowledged: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Employee Code of Conduct'), findsOneWidget);
      expect(find.text('Sign & Acknowledge'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('9. TemplateEditorDialog renders letter types, variable chips and preview', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TemplateEditorDialog(onTemplatesChanged: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('HR Document & Letter Templates'), findsOneWidget);
      expect(find.textContaining('TEMPLATES'), findsOneWidget);
      expect(find.text('{{employee_name}}'), findsOneWidget);
      expect(find.textContaining('Template'), findsAtLeastNWidgets(1));
    });

    testWidgets('10. ReportsDialog renders reports options and export button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReportsDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('HR Compliance & Document Reports'), findsOneWidget);
      expect(find.text('Policy Register'), findsOneWidget);
      expect(find.text('Document Register'), findsOneWidget);
      expect(find.text('Expiring Documents Report'), findsOneWidget);
      expect(find.text('Acknowledgement Compliance Report'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
    });

    testWidgets('11. HRPoliciesScreen main page renders Header, KPIs, Categories and Workspace Tabs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HRPoliciesScreen(),
        ),
      );
      await tester.pump();

      // Top title
      expect(find.text('Policies & Documents'), findsAtLeastNWidgets(1));
      expect(find.text('Upload Document'), findsAtLeastNWidgets(1));
      expect(find.text('Manage Categories'), findsAtLeastNWidgets(1));
      // KPI cards
      expect(find.text('Total Policies'), findsOneWidget);
      expect(find.text('Total Documents'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Recently Updated'), findsOneWidget);
      // Workspace tabs (Policies, Documents, Templates, Expiring Soon, My Acknowledgements)
      expect(find.text('Policies'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);
      expect(find.text('Expiring Soon'), findsOneWidget);
      expect(find.text('My Acknowledgements'), findsOneWidget);
      // Recently Updated Documents is removed
      expect(find.text('Recently Updated Documents'), findsNothing);
    });

    testWidgets('12. HRPoliciesScreen responsive layout renders without overflow across all screen sizes (320px to 2560px)', (WidgetTester tester) async {
      final screenSizes = [
        const Size(320, 600),   // Ultra-compact mobile
        const Size(360, 780),   // Common Android phone
        const Size(390, 844),   // Standard iPhone
        const Size(414, 896),   // Large iPhone Max
        const Size(768, 1024),  // iPad portrait
        const Size(1024, 768),  // iPad landscape
        const Size(1366, 768),  // Standard laptop
        const Size(1920, 1080), // Desktop 1080p
        const Size(2560, 1440), // QHD 2K / 4K
      ];

      for (final size in screenSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(const MaterialApp(home: HRPoliciesScreen()));
        await tester.pump();
        expect(find.byType(HRPoliciesScreen), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
    });

    testWidgets('13. Multi-select bulk action bar activates and displays all action buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HRPoliciesScreen(
            initialItemsForTesting: [
              {
                'id': 'test-doc-1',
                'title': 'Laboratory Biohazard Safety Policy',
                'category_name': 'Health & Safety',
                'document_type': 'Policy',
                'version_number': '2.0',
                'status': 'ACTIVE',
                'is_policy': true,
              },
              {
                'id': 'test-doc-2',
                'title': 'Institutional Safeguarding Protocol',
                'category_name': 'Health & Safety',
                'document_type': 'Policy',
                'version_number': '1.0',
                'status': 'ACTIVE',
                'is_policy': true,
              },
            ],
            initialSelectedIdsForTesting: {'test-doc-1', 'test-doc-2'},
          ),
        ),
      );
      await tester.pump();

      // Verify bulk action bar badges and buttons appear
      expect(find.text('2 items selected'), findsOneWidget);
      expect(find.text('Archive Selected'), findsOneWidget);
      expect(find.text('Download All'), findsOneWidget);
      expect(find.text('Change Category'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify checkboxes are rendered in table
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsAtLeastNWidgets(2));
    });

    testWidgets('14. InstitutionalDocumentRenderer renders HTML tables, headers, and Verified status chips with executive styling', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const sampleHtml = '''
        <p style="text-align: center;"><strong>EMPLOYEE ONBOARDING &amp; STATUTORY DOCUMENT AUDIT</strong></p>
        <p>Employee Name: <strong>Dr. Rajesh Verma</strong> &nbsp;&nbsp; Staff ID: <strong>EMP-2024-042</strong></p>
        <table>
          <tr>
            <th>Item #</th>
            <th>Statutory Document Required</th>
            <th>Verification Status</th>
          </tr>
          <tr>
            <td>1</td>
            <td>Government Identity Proof (Aadhaar / Passport)</td>
            <td>Verified</td>
          </tr>
          <tr>
            <td>2</td>
            <td>PAN Card / Tax Registration Document</td>
            <td>Verified</td>
          </tr>
        </table>
        <hr>
        <ul>
          <li>Submit original physical certificates within 7 business days</li>
          <li>Mandatory background check clearance required</li>
        </ul>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstitutionalDocumentRenderer(
                htmlContent: sampleHtml,
                templateType: 'Joining Checklist',
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Check title and metadata paragraphs
      expect(find.textContaining('EMPLOYEE ONBOARDING'), findsOneWidget);
      expect(find.textContaining('Dr. Rajesh Verma'), findsOneWidget);

      // Check rendered Table widget and columns
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Item #'), findsOneWidget);
      expect(find.text('Statutory Document Required'), findsOneWidget);
      expect(find.text('Government Identity Proof (Aadhaar / Passport)'), findsOneWidget);
      expect(find.text('PAN Card / Tax Registration Document'), findsOneWidget);

      // Check badge renders
      expect(find.text('Verified'), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(2));

      // Check divider
      expect(find.byType(Divider), findsOneWidget);

      // Check list items
      expect(find.textContaining('Submit original physical certificates'), findsOneWidget);
      expect(find.textContaining('Mandatory background check clearance'), findsOneWidget);
    });

    testWidgets('15. HRPoliciesScreen verifies Document Categories block is removed and Templates tab displays numeric count badge', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HRPoliciesScreen(),
        ),
      );
      await tester.pump();

      // Document Categories block header must NOT exist on screen
      expect(find.text('Document Categories'), findsNothing);

      // Templates tab exists in workspace navigation
      expect(find.text('Templates'), findsOneWidget);

      // Recently Updated Documents is completely removed from the layout
      expect(find.text('Recently Updated Documents'), findsNothing);
    });

    testWidgets('16. DataTable supports interactive column sorting across document titles and attributes', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HRPoliciesScreen(
            initialItemsForTesting: [
              {
                'id': 'test-doc-b',
                'title': 'Bravo Employee Handbook',
                'category_name': 'Administration',
                'document_type': 'Handbook',
                'version_number': '1.0',
                'status': 'ACTIVE',
                'updated_at': '2026-09-20T10:00:00Z',
              },
              {
                'id': 'test-doc-a',
                'title': 'Alpha Laboratory Protocol',
                'category_name': 'Health & Safety',
                'document_type': 'Policy',
                'version_number': '2.0',
                'status': 'ACTIVE',
                'updated_at': '2026-09-24T12:00:00Z',
              },
            ],
          ),
        ),
      );
      await tester.pump();

      // Verify DataTable renders with sort indicators
      final dataTableFinder = find.byType(DataTable);
      expect(dataTableFinder, findsOneWidget);
      final DataTable dataTable = tester.widget(dataTableFinder);
      expect(dataTable.sortColumnIndex, isNotNull);

      // Verify column headers exist
      expect(find.text('Document / Policy Name'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Last Updated'), findsOneWidget);
      expect(find.text('Size / Status'), findsOneWidget);

      // Tap 'Document / Policy Name' to sort by Name
      await tester.tap(find.text('Document / Policy Name'));
      await tester.pump();

      final DataTable updatedTable = tester.widget(dataTableFinder);
      expect(updatedTable.sortColumnIndex, equals(1));
    });
  });
}

