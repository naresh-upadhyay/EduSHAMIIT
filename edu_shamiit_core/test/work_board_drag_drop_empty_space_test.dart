import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/board/work_board_tab_view.dart';

const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class FakeBoardApiService extends WorkApiService {
  @override
  Future<List<WorkAssigneeModel>> getAssignableUsers({
    String? q,
    String? role,
    String? department,
    int limit = 100,
  }) async {
    return const [
      WorkAssigneeModel(id: '1', userId: 'u1', fullName: 'Amit Kumar', role: 'Teacher'),
    ];
  }

  @override
  Future<bool> transitionStatus(String itemId, String status, {String? notes}) async {
    return true;
  }
}

class TestWorkBoardNotifier extends WorkBoardNotifier {
  final WorkBoardState testState;
  TestWorkBoardNotifier(this.testState);

  @override
  WorkBoardState get state => testState;

  bool transitionCalled = false;
  String? lastTransitionItemId;
  String? lastTransitionNewStatus;

  @override
  Future<bool> transitionStatus(String itemId, String newStatus, {String? notes}) async {
    transitionCalled = true;
    lastTransitionItemId = itemId;
    lastTransitionNewStatus = newStatus;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  testWidgets('Board columns extend uniform height and accept drag-and-drop into empty space', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const item1 = WorkItemModel(
      id: 'item-1',
      itemNumber: 'TK-101',
      title: 'Task in New Column',
      workType: 'TASK',
      priority: 'MEDIUM',
      status: 'NEW',
    );

    const item2 = WorkItemModel(
      id: 'item-2',
      itemNumber: 'TK-102',
      title: 'Task in Resolved Column',
      workType: 'TASK',
      priority: 'MEDIUM',
      status: 'RESOLVED',
    );

    const testBoardState = WorkBoardState(
      isLoading: false,
      columns: [
        KanbanColumnModel(
          statusKey: 'NEW',
          name: 'New',
          color: '#64748B',
          count: 1,
          items: [item1],
        ),
        KanbanColumnModel(
          statusKey: 'ACTIVE',
          name: 'Active',
          color: '#3B82F6',
          count: 0,
          items: [],
        ),
        KanbanColumnModel(
          statusKey: 'RESOLVED',
          name: 'Resolved',
          color: '#10B981',
          count: 1,
          items: [item2],
        ),
        KanbanColumnModel(
          statusKey: 'COMPLETED',
          name: 'Completed',
          color: '#8B5CF6',
          count: 0,
          items: [],
        ),
      ],
    );

    final mockNotifier = TestWorkBoardNotifier(testBoardState);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workApiServiceProvider.overrideWithValue(FakeBoardApiService()),
          workBoardProvider.overrideWith((ref) => mockNotifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WorkBoardTabView(
              onOpenDetail: (_) {},
              onQuickAction: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 4 DragTarget columns rendered
    final dragTargets = find.byType(DragTarget<WorkItemModel>);
    expect(dragTargets, findsNWidgets(4));

    // Verify all 4 columns have at least 650px height
    for (int i = 0; i < 4; i++) {
      final size = tester.getSize(dragTargets.at(i));
      expect(size.height, greaterThanOrEqualTo(650.0));
    }

    // Drag item1 from "New" and drop onto the empty space of "Resolved" column (near bottom)
    final resolvedTarget = dragTargets.at(2);
    final resolvedBottomOffset = tester.getBottomLeft(resolvedTarget) + const Offset(50, -50);

    // Start dragging item1
    final gesture = await tester.startGesture(tester.getCenter(find.text('TK-101')));
    await tester.pump(const Duration(milliseconds: 100));

    // Move over the empty space in Resolved column
    await gesture.moveTo(resolvedBottomOffset);
    await tester.pump(const Duration(milliseconds: 100));

    // Drop
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify transitionStatus was called with item-1 and RESOLVED
    expect(mockNotifier.transitionCalled, isTrue);
    expect(mockNotifier.lastTransitionItemId, equals('item-1'));
    expect(mockNotifier.lastTransitionNewStatus, equals('RESOLVED'));
  });
}
