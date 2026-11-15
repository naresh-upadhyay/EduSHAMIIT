import 'package:edu_shamiit_core/screens/live_classes/whiteboard/models/whiteboard_models.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/providers/whiteboard_provider.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/widgets/equation_editor_dialog.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/widgets/whiteboard_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestWhiteboardNotifier extends WhiteboardNotifier {
  _TestWhiteboardNotifier(WhiteboardState initial) : super() {
    state = initial;
  }

  @override
  Future<void> initializeForSession(String? sessionId, {String defaultTitle = 'Whiteboard - Class 10 – Mathematics'}) async {}

  @override
  Future<void> addObject(WhiteboardObject obj, {bool recordUndo = true}) async {
    final doc = state.document;
    final page = state.activePage;
    if (doc == null || page == null) return;
    final nextObjs = List<WhiteboardObject>.from(page.objects)..add(obj);
    final nextPages = doc.pages.map((p) => p.id == page.id ? p.copyWith(objects: nextObjs) : p).toList();
    final undo = recordUndo
        ? (List<WhiteboardUndoEntry>.from(state.undoStack)
          ..add(WhiteboardUndoEntry(
            pageId: page.id,
            actionType: 'create',
            beforeObjects: const [],
            afterObjects: [obj],
          )))
        : state.undoStack;
    state = state.copyWith(
      document: doc.copyWith(pages: nextPages),
      undoStack: undo,
      redoStack: recordUndo ? [] : state.redoStack,
      saveState: WhiteboardSaveState.saved,
    );
  }

  @override
  Future<void> deleteObjectById(String objectId, {bool recordUndo = true}) async {
    final doc = state.document;
    final page = state.activePage;
    if (doc == null || page == null) return;
    final before = page.objects.where((o) => o.id == objectId).toList();
    if (before.isEmpty) return;
    final nextObjs = page.objects.where((o) => o.id != objectId).toList();
    final nextPages = doc.pages.map((p) => p.id == page.id ? p.copyWith(objects: nextObjs) : p).toList();
    final undo = recordUndo
        ? (List<WhiteboardUndoEntry>.from(state.undoStack)
          ..add(WhiteboardUndoEntry(
            pageId: page.id,
            actionType: 'delete',
            beforeObjects: before,
            afterObjects: const [],
          )))
        : state.undoStack;
    state = state.copyWith(
      document: doc.copyWith(pages: nextPages),
      selectedObjectIds: Set<String>.from(state.selectedObjectIds)..remove(objectId),
      undoStack: undo,
      redoStack: recordUndo ? [] : state.redoStack,
    );
  }
}

WhiteboardDocument _sampleDocument() {
  return const WhiteboardDocument(
    id: 'wb-test-1',
    sessionId: 'sess-test-1',
    title: 'Whiteboard - Class 10 – Mathematics',
    collaborationEnabled: true,
    pages: [
      WhiteboardPage(
        id: 'page-1',
        whiteboardId: 'wb-test-1',
        title: '1. Quadratic Equations',
        pageOrder: 1,
        backgroundType: WhiteboardBackgroundType.plain,
        objects: [
          WhiteboardObject(
            id: 'eq-1',
            pageId: 'page-1',
            type: 'equation',
            data: {
              'x': 120,
              'y': 100,
              'width': 280,
              'height': 60,
              'latex': 'ax^2 + bx + c = 0',
              'display': 'ax² + bx + c = 0',
            },
          ),
        ],
      ),
      WhiteboardPage(
        id: 'page-2',
        whiteboardId: 'wb-test-1',
        title: '2. Discriminant',
        pageOrder: 2,
        backgroundType: WhiteboardBackgroundType.lightGrid,
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('WhiteboardObject geometry hitTest, movedBy, and resizedTo work accurately', () {
    const rectObj = WhiteboardObject(
      id: 'r1',
      pageId: 'p1',
      type: 'rectangle',
      data: {'x': 100.0, 'y': 100.0, 'width': 80.0, 'height': 50.0},
    );
    expect(rectObj.hitTest(const Offset(140, 125)), isTrue);
    expect(rectObj.hitTest(const Offset(300, 300)), isFalse);

    final moved = rectObj.movedBy(20, -10);
    expect(moved.getBounds().left, 120.0);
    expect(moved.getBounds().top, 90.0);

    final resized = moved.resizedTo(const Rect.fromLTWH(120, 90, 160, 100));
    expect(resized.getBounds().width, 160.0);
    expect(resized.getBounds().height, 100.0);

    expect(WhiteboardBackgroundTypeExt.fromApi('graph'), WhiteboardBackgroundType.graph);
    expect(WhiteboardBackgroundType.engineering.apiValue, 'engineering');
  });

  test('WhiteboardNotifier tool selection, zoom/pan, copy/paste, undo/redo work end-to-end', () async {
    final doc = _sampleDocument();
    final notifier = _TestWhiteboardNotifier(
      WhiteboardState(document: doc, activePageId: 'page-1'),
    );

    notifier.setTool(WhiteboardTool.equation);
    expect(notifier.state.activeTool, WhiteboardTool.equation);

    notifier.zoomIn();
    expect(notifier.state.zoom, greaterThan(1.0));
    notifier.resetView();
    expect(notifier.state.zoom, 1.0);

    // Add stroke -> Undo -> Redo
    await notifier.addObject(const WhiteboardObject(
      id: 'stroke-new',
      pageId: 'page-1',
      type: 'stroke',
      data: {'points': [[10, 10], [50, 50]], 'color': '#2563EB'},
    ));
    expect(notifier.state.activePage!.objects.length, 2);

    await notifier.undo();
    expect(notifier.state.activePage!.objects.length, 1);

    await notifier.redo();
    expect(notifier.state.activePage!.objects.length, 2);

    // Select -> Copy -> Paste -> Duplicate
    notifier.selectObjects({'eq-1'});
    notifier.copySelected();
    await notifier.pasteClipboard();
    expect(notifier.state.activePage!.objects.length, 3);

    // Page switching
    notifier.selectPage('page-2');
    expect(notifier.state.activePageId, 'page-2');
  });

  testWidgets('WhiteboardWorkspace renders responsive layout matching design without overflows', (tester) async {
    final doc = _sampleDocument();
    final testNotifier = _TestWhiteboardNotifier(
      WhiteboardState(
        document: doc,
        activePageId: 'page-1',
        wsConnected: true,
        saveState: WhiteboardSaveState.saved,
      ),
    );

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          whiteboardProvider.overrideWith((ref) => testNotifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: WhiteboardWorkspace(
                  sessionId: 'sess-test-1',
                  sessionTitle: 'Whiteboard - Class 10 – Mathematics',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Open Whiteboard'), findsOneWidget);
    expect(find.text('Boards (2)'), findsOneWidget);
    expect(find.text('1. Quadratic Equations'), findsOneWidget);
    expect(find.text('2. Discriminant'), findsOneWidget);
    expect(find.text('New Board'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('End Class'), findsOneWidget);

    // Switch to compact tablet/mobile width and verify zero overflow
    tester.view.physicalSize = const Size(820, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('EquationEditorDialog inserts preset formula and returns LaTeX payload', (tester) async {
    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: ctx,
                  builder: (_) => const EquationEditorDialog(),
                );
              },
              child: const Text('Open Eq'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Eq'));
    await tester.pumpAndSettle();
    expect(find.text('Mathematical Equation Editor'), findsOneWidget);

    await tester.tap(find.text('Pythagorean'));
    await tester.pump();
    await tester.tap(find.text('Insert Equation'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!['latex'], 'a² + b² = c²');
  });
}
