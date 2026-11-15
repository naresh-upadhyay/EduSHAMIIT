import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/models/document_model.dart';
import 'package:edu_shamiit_core/screens/documents/widgets/document_kpi_cards.dart';
import 'package:edu_shamiit_core/screens/documents/widgets/folder_tree_panel.dart';
import 'package:edu_shamiit_core/screens/documents/widgets/document_grid_card.dart';
import 'package:edu_shamiit_core/screens/documents/widgets/document_preview_panel.dart';
import 'package:edu_shamiit_core/screens/documents/widgets/document_dialogs.dart';

void main() {
  group('Documents Management Models & Formatting', () {
    test('DocumentModel parses correctly from json and computes badges', () {
      final json = {
        'id': 'a0000001-0000-0000-0000-000000000001',
        'school_id': '11111111-1111-1111-1111-111111111111',
        'owner_id': '5198c4b0-f1cb-45db-9649-41688d0438ba',
        'owner_name': 'Admin',
        'title': 'Academic Calendar 2025-26',
        'description': 'Annual schedule',
        'category': 'academic',
        'file_name': 'Academic_Calendar_2025-26.pdf',
        'file_size': 2516582,
        'mime_type': 'application/pdf',
        'file_type': 'PDF',
        'approval_status': 'Approved',
        'version_number': 1,
        'is_starred': true,
        'created_at': '2026-08-10T10:24:00Z',
        'updated_at': '2026-08-10T10:24:00Z',
      };

      final doc = DocumentModel.fromJson(json);
      expect(doc.id, 'a0000001-0000-0000-0000-000000000001');
      expect(doc.title, 'Academic Calendar 2025-26');
      expect(doc.fileType, 'PDF');
      expect(doc.fileSizeLabel, '2.4 MB');
      expect(doc.fileTypeBadgeColor, const Color(0xFFEF4444)); // Red for PDF
      expect(doc.isStarred, isTrue);
      expect(doc.approvalStatus, 'Approved');
    });

    test('FolderModel parses hierarchy, icons, and tree count', () {
      final json = {
        'id': 'f0000001-0000-0000-0000-000000000001',
        'name': 'Academic Documents',
        'category': 'Academic',
        'color': '#2563EB',
        'icon': 'school',
        'document_count': 52,
        'total_tree_count': 52,
        'children': [
          {
            'id': 'f0000011-0000-0000-0000-000000000011',
            'name': 'Syllabus',
            'document_count': 18,
            'children': [],
          }
        ],
      };

      final folder = FolderModel.fromJson(json);
      expect(folder.name, 'Academic Documents');
      expect(folder.documentCount, 52);
      expect(folder.children.length, 1);
      expect(folder.children.first.name, 'Syllabus');
      expect(folder.iconData, Icons.school_rounded);
    });

    test('DocumentStatsModel parses storage metrics correctly', () {
      final json = {
        'total_documents': 248,
        'shared_documents': 86,
        'storage_used_bytes': 260046848,
        'storage_used_label': '248 MB',
        'storage_quota_bytes': 5368709120,
        'storage_quota_label': '5 GB',
        'storage_percentage': 5,
        'recent_uploads': 12,
        'recent_today': 2,
        'pending_approvals': 4,
        'expiring_soon': 3,
      };

      final stats = DocumentStatsModel.fromJson(json);
      expect(stats.totalDocuments, 248);
      expect(stats.sharedDocuments, 86);
      expect(stats.storageUsedLabel, '248 MB');
      expect(stats.storageQuotaLabel, '5 GB');
      expect(stats.storagePercentage, 5);
      expect(stats.recentUploads, 12);
      expect(stats.recentToday, 2);
    });
  });

  group('Documents Management Widget Rendering', () {
    testWidgets('DocumentKpiCards renders 4 dashboard metric cards', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const stats = DocumentStatsModel(
        totalDocuments: 248,
        sharedDocuments: 86,
        storageUsedLabel: '248 MB',
        storageQuotaLabel: '5 GB',
        storagePercentage: 5,
        recentUploads: 12,
        recentToday: 2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DocumentKpiCards(stats: stats),
          ),
        ),
      );

      expect(find.text('Total Documents'), findsOneWidget);
      expect(find.text('248'), findsOneWidget);
      expect(find.text('Shared Documents'), findsOneWidget);
      expect(find.text('86'), findsOneWidget);
      expect(find.text('Storage Used'), findsOneWidget);
      expect(find.text('248 MB / 5 GB'), findsOneWidget);
      expect(find.text('Recent Uploads'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('FolderTreePanel renders folders and storage usage progress', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final folders = [
        const FolderModel(
          id: 'f1',
          name: 'Academic Documents',
          documentCount: 52,
          totalTreeCount: 52,
          children: [
            FolderModel(id: 'sub1', name: 'Syllabus', documentCount: 18),
            FolderModel(id: 'sub2', name: 'Question Papers', documentCount: 16),
          ],
        ),
        const FolderModel(id: 'f2', name: 'Administration', documentCount: 64, totalTreeCount: 64),
      ];

      const stats = DocumentStatsModel(
        storagePercentage: 5,
        storageUsedLabel: '248 MB',
        storageQuotaLabel: '5 GB',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              height: 700,
              child: FolderTreePanel(
                folders: folders,
                activeFolderId: null,
                totalDocuments: 248,
                stats: stats,
                onFolderSelected: (_) {},
                onNewFolder: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Folders'), findsOneWidget);
      expect(find.text('New Folder'), findsOneWidget);
      expect(find.text('All Documents'), findsOneWidget);
      expect(find.text('Academic Documents'), findsOneWidget);
      expect(find.text('Administration'), findsOneWidget);
      expect(find.text('Storage Usage'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('Upgrade Plan'), findsNothing);
    });

    testWidgets('DocumentGridCard renders title, badge, metadata and handles tap', (tester) async {
      final doc = DocumentModel(
        id: 'doc1',
        schoolId: 's1',
        ownerId: 'u1',
        ownerName: 'Admin',
        title: 'Fee Structure 2025-26',
        category: DocumentCategory.finance,
        fileType: 'DOCX',
        fileSize: 1153433,
        createdAt: DateTime(2025, 8, 8),
        updatedAt: DateTime(2025, 8, 8),
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentGridCard(
              document: doc,
              isSelected: true,
              isBulkSelected: false,
              onTap: () => tapped = true,
              onPreview: () {},
              onDownload: () {},
              onShare: () {},
              onToggleStar: () {},
              onVersions: () {},
              onDelete: () {},
              onSelectCheckbox: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Fee Structure 2025-26'), findsOneWidget);
      expect(find.text('DOCX'), findsOneWidget);
      expect(find.text('DOCX • 1.1 MB'), findsOneWidget);
      expect(find.text('Aug 08, 2025'), findsOneWidget);

      await tester.tap(find.text('Fee Structure 2025-26'));
      expect(tapped, isTrue);
    });

    testWidgets('DocumentPreviewPanel renders file details and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final doc = DocumentModel(
        id: 'doc1',
        schoolId: 's1',
        ownerId: 'u1',
        ownerName: 'Admin',
        title: 'Academic Calendar 2025-26',
        fileName: 'Academic_Calendar_2025-26.pdf',
        fileType: 'PDF',
        fileSize: 2516582,
        folderName: 'Academic Documents',
        approvalStatus: 'Approved',
        versionNumber: 1,
        category: DocumentCategory.academic,
        createdAt: DateTime(2025, 8, 10, 10, 24),
        updatedAt: DateTime(2025, 8, 10, 10, 24),
      );

      bool downloadTriggered = false;
      bool shareTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 800,
              child: DocumentPreviewPanel(
                document: doc,
                onDownload: () => downloadTriggered = true,
                onShare: () => shareTriggered = true,
                onFullscreen: () {},
                onExternalOpen: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Document Preview'), findsOneWidget);
      expect(find.text('File Details'), findsOneWidget);
      expect(find.text('Academic_Calendar_2025-26.pdf'), findsOneWidget);
      expect(find.text('2.4 MB'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Academic Documents'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('v1.0'), findsOneWidget);
      expect(find.text('Share Document'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);

      await tester.tap(find.text('Download'));
      expect(downloadTriggered, isTrue);

      await tester.tap(find.text('Share Document'));
      expect(shareTriggered, isTrue);
    });

    testWidgets('BulkActionBar renders selected count and actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool bulkMoveCalled = false;
      bool clearCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: BulkActionBar(
                selectedCount: 3,
                onBulkMove: () => bulkMoveCalled = true,
                onBulkStar: () {},
                onBulkDownload: () {},
                onBulkTrash: () {},
                onClear: () => clearCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('3 Selected'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
      expect(find.text('Star'), findsOneWidget);
      expect(find.text('Download ZIP'), findsOneWidget);
      expect(find.text('Move to Trash'), findsOneWidget);

      await tester.tap(find.text('Move'));
      expect(bulkMoveCalled, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(clearCalled, isTrue);
    });

    testWidgets('BulkActionBar triggers onBulkDownload when Download ZIP is tapped', (tester) async {
      bool downloadZipCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: BulkActionBar(
                selectedCount: 4,
                onBulkMove: () {},
                onBulkStar: () {},
                onBulkDownload: () => downloadZipCalled = true,
                onBulkTrash: () {},
                onClear: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Download ZIP'), findsOneWidget);
      await tester.tap(find.text('Download ZIP'));
      expect(downloadZipCalled, isTrue);
    });

    testWidgets('FolderTreePanel renders empty folder delete icon and triggers deletion', (tester) async {
      final folders = [
        const FolderModel(
          id: 'f1',
          name: 'Empty Folder',
          category: 'General',
          color: Color(0xFF2563EB),
          icon: 'folder',
          documentCount: 0,
          children: [],
        ),
      ];

      FolderModel? deletedFolder;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 600,
              child: FolderTreePanel(
                folders: folders,
                activeFolderId: null,
                totalDocuments: 10,
                stats: const DocumentStatsModel(),
                onFolderSelected: (_) {},
                onNewFolder: () {},
                onDeleteFolder: (f) => deletedFolder = f,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Empty Folder'), findsOneWidget);
      // Empty folder shows the red delete icon
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Delete "Empty Folder"?'), findsOneWidget);
      expect(find.text('This folder is empty. Are you sure you want to delete it?'), findsOneWidget);

      await tester.tap(find.text('Delete Folder'));
      await tester.pumpAndSettle();

      expect(deletedFolder?.name, 'Empty Folder');
    });

    testWidgets('DocumentPreviewPanel renders collaborative editor banner for DOCX and XLSX', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final doc = DocumentModel(
        id: 'docx1',
        schoolId: 's1',
        ownerId: 'u1',
        ownerName: 'Admin',
        title: 'Curriculum_Draft.docx',
        fileType: 'DOCX',
        fileSize: 45000,
        category: DocumentCategory.academic,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 800,
              child: DocumentPreviewPanel(
                document: doc,
                onDownload: () {},
                onShare: () {},
                onFullscreen: () {},
                onExternalOpen: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Collaborative Word Document'), findsOneWidget);
      expect(find.text('Open Collaborative Document'), findsOneWidget);
      expect(find.text('Copy Live Share Link'), findsOneWidget);
    });

    testWidgets('ShareDocumentDialog renders user search, role tabs, and permission dropdown', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final doc = DocumentModel(
        id: 'share1',
        schoolId: 's1',
        ownerId: 'u1',
        ownerName: 'Admin',
        title: 'Final Exam Draft',
        category: DocumentCategory.academic,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareDocumentDialog(
              document: doc,
              currentShares: const [],
              onSearchUsers: (q) async => [
                {'id': 'u101', 'full_name': 'Prof. Rahul Verma', 'email': 'rahul@school.edu', 'role': 'Teacher'}
              ],
              onShare: ({required docId, required shareType, targetId, targetName, permissionLevel = 'Viewer', allowDownload = true, allowPrint = true, expiryDate, message}) async => true,
              onRevoke: (sId, dId) async => true,
            ),
          ),
        ),
      );

      expect(find.text('Share "Final Exam Draft"'), findsOneWidget);
      expect(find.text('Individual User'), findsOneWidget);
      expect(find.text('By Role'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Class/Section'), findsOneWidget);
      expect(find.text('Send Share Invitation'), findsOneWidget);
      expect(find.text('Allow recipients to download this file'), findsOneWidget);
    });

    testWidgets('DocumentPreviewPanel renders Trashed Document banner with Restore and Delete Forever', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool restoreCalled = false;
      bool deleteCalled = false;

      final doc = DocumentModel(
        id: 'trash1',
        schoolId: 's1',
        ownerId: 'u1',
        ownerName: 'Admin',
        title: 'Old_Report.pdf',
        fileType: 'PDF',
        fileSize: 1024,
        isDeleted: true,
        category: DocumentCategory.academic,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 800,
              child: DocumentPreviewPanel(
                document: doc,
                onDownload: () {},
                onShare: () {},
                onFullscreen: () {},
                onExternalOpen: () {},
                onRestore: () => restoreCalled = true,
                onPermanentDelete: () => deleteCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Document is in Trash'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Delete Forever'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      await tester.pump();
      expect(restoreCalled, isTrue);

      await tester.tap(find.text('Delete Forever'));
      await tester.pump();
      expect(deleteCalled, isTrue);
    });

    testWidgets('DocumentPreviewPanel renders Pending Approval banner with Approve and Reject', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? approvedAction;

      final doc = DocumentModel(
        id: 'pending1',
        schoolId: 's1',
        ownerId: 'u2',
        ownerName: 'Teacher',
        title: 'Exam_Questions.pdf',
        fileType: 'PDF',
        fileSize: 2048,
        approvalStatus: 'Pending',
        category: DocumentCategory.academic,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 800,
              child: DocumentPreviewPanel(
                document: doc,
                onDownload: () {},
                onShare: () {},
                onFullscreen: () {},
                onExternalOpen: () {},
                onApprovalAction: (status, comments) {
                  approvedAction = status;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Approval Required'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(approvedAction, 'Approved');
    });

    testWidgets('BulkActionBar renders trash mode buttons when isTrashTab is true', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool bulkRestoreCalled = false;
      bool bulkDeleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkActionBar(
              selectedCount: 4,
              onBulkMove: () {},
              onBulkStar: () {},
              onBulkDownload: () {},
              onBulkTrash: () => bulkDeleteCalled = true,
              onClear: () {},
              isTrashTab: true,
              onBulkRestore: () => bulkRestoreCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('4 Selected'), findsOneWidget);
      expect(find.text('Restore Selected'), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);

      await tester.tap(find.text('Restore Selected'));
      await tester.pump();
      expect(bulkRestoreCalled, isTrue);

      await tester.tap(find.text('Delete Permanently'));
      await tester.pump();
      expect(bulkDeleteCalled, isTrue);
    });

    testWidgets('DocumentRequestsManagerDialog renders requests and status chips', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final requests = [
        DocumentRequestModel(
          id: 'req1',
          requesterName: 'Priya Sharma',
          title: 'Annual Budget Draft',
          category: 'Accounts',
          priority: 'High',
          status: 'New',
          description: 'Urgent for audit',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentRequestsManagerDialog(
              requests: requests,
              availableDocuments: const [],
              onRefresh: ({status}) async {},
              onUpdateStatus: (reqId, {required status, responseNotes}) async => true,
              onFulfill: (reqId, {required documentId, responseNotes}) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Document Requests Review & Fulfillment'), findsOneWidget);
      expect(find.text('Annual Budget Draft'), findsOneWidget);
      expect(find.textContaining('Accounts'), findsOneWidget);
      expect(find.textContaining('Priya Sharma'), findsOneWidget);
      expect(find.text('Fulfill'), findsOneWidget);
    });
  });
}
