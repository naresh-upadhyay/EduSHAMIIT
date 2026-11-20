import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/app_config.dart';
import '../models/whiteboard_models.dart';
import '../providers/whiteboard_provider.dart';

const _uuid = Uuid();

class WhiteboardImageCache {
  static final Map<String, ui.Image> _cache = {};
  static final Set<String> _loading = {};

  static ui.Image? getOrLoad(String contentUrl, VoidCallback onLoaded) {
    if (contentUrl.isEmpty) return null;
    if (_cache.containsKey(contentUrl)) return _cache[contentUrl];
    if (_loading.contains(contentUrl)) return null;

    _loading.add(contentUrl);
    _fetchImage(contentUrl).then((img) {
      _loading.remove(contentUrl);
      if (img != null) {
        _cache[contentUrl] = img;
        onLoaded();
      }
    });
    return null;
  }

  static Future<ui.Image?> _fetchImage(String contentUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final fullUrl = contentUrl.startsWith('http')
          ? contentUrl
          : '${AppConfig.baseUrl}$contentUrl';
      final res = await http.get(
        Uri.parse(fullUrl),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final completer = Completer<ui.Image>();
        ui.decodeImageFromList(Uint8List.fromList(res.bodyBytes), (img) {
          completer.complete(img);
        });
        return await completer.future;
      }
    } catch (_) {}
    return null;
  }
}

class WhiteboardCanvasEngine extends ConsumerStatefulWidget {
  final void Function(WhiteboardObject? existing, Offset logicalPos)? onEditText;
  final void Function(WhiteboardObject? existing, Offset logicalPos)? onEditEquation;
  final VoidCallback? onRequestImageUpload;

  const WhiteboardCanvasEngine({
    super.key,
    this.onEditText,
    this.onEditEquation,
    this.onRequestImageUpload,
  });

  @override
  ConsumerState<WhiteboardCanvasEngine> createState() => _WhiteboardCanvasEngineState();
}

class _WhiteboardCanvasEngineState extends ConsumerState<WhiteboardCanvasEngine> {
  // Active local transient drawing state (not committed to provider until pointer up)
  String? _activeStrokeId;
  List<Offset> _activePoints = [];
  List<double> _activePressures = [];
  Offset? _shapeStart;
  Offset? _shapeCurrent;
  Rect? _areaEraseRect;

  // Ephemeral smooth drag & resize state (60-120 FPS buttery rendering)
  bool _isDraggingSelection = false;
  bool _isResizingSelection = false;
  Offset _dragAccumulatedDelta = Offset.zero;
  Set<String> _draggedObjectIds = {};
  Rect? _resizingRect;
  String? _resizingObjectId;

  // Dynamic Chaining & Connector Ports state
  bool _isConnectingNodes = false;
  String? _connectingFromNodeId;
  String? _connectingHoverTargetId;
  Offset? _connectingStartPos;
  Offset? _connectingCurrentPos;

  Offset? _lastDragLogical;
  Offset? _panStartScreen;
  Offset? _panStartOffset;
  int _repaintTick = 0;
  DateTime? _lastTapTime;
  String? _lastHitObjectId;

  Offset _toLogical(Offset localPos, WhiteboardState s) {
    return (localPos - s.panOffset) / s.zoom;
  }

  // --- Mind Map Structure & Hierarchy Helpers ---
  static Set<String> _getChildrenOf(String parentId, WhiteboardPage page) {
    final childIds = <String>{};
    for (final o in page.objects) {
      if (o.data['parentNodeId'] == parentId || o.data['parentId'] == parentId) {
        childIds.add(o.id);
      } else if (o.isLineBased && (o.data['startNodeId'] == parentId || o.data['fromId'] == parentId)) {
        final targetId = (o.data['endNodeId'] ?? o.data['toId'])?.toString();
        if (targetId != null && targetId.isNotEmpty && targetId != parentId) {
          childIds.add(targetId);
        }
      }
    }
    return childIds;
  }

  static void _collectSubtree(String rootId, WhiteboardPage page, Set<String> collected) {
    final direct = _getChildrenOf(rootId, page);
    for (final cid in direct) {
      if (collected.add(cid)) {
        _collectSubtree(cid, page, collected);
      }
    }
  }

  static Set<String> _getCollapsedHiddenObjectIds(WhiteboardPage? page) {
    if (page == null) return const <String>{};
    final hiddenNodes = <String>{};
    for (final o in page.objects) {
      if (o.data['collapsed'] == true) {
        _collectSubtree(o.id, page, hiddenNodes);
      }
    }
    final allHidden = Set<String>.from(hiddenNodes);
    for (final o in page.objects) {
      if (o.isLineBased) {
        final sId = o.data['startNodeId'] ?? o.data['fromId'];
        final eId = o.data['endNodeId'] ?? o.data['toId'];
        if (hiddenNodes.contains(sId) || hiddenNodes.contains(eId)) {
          allHidden.add(o.id);
        }
      }
    }
    return allHidden;
  }

  Future<void> _addMindMapChildNode(
    WhiteboardObject parentNode,
    WhiteboardState s,
    WhiteboardNotifier notifier,
  ) async {
    final page = s.activePage;
    if (page == null) return;
    final pBounds = parentNode.getBounds();
    final existingChildren = page.objects
        .where((o) => o.data['parentNodeId'] == parentNode.id || o.data['parentId'] == parentNode.id)
        .toList();
    final childCount = existingChildren.length;

    // Stagger child nodes vertically around parent's right side
    final double childX = pBounds.right + 110.0;
    final double childY = pBounds.top + (childCount * 80.0) - (childCount > 1 ? 25.0 : 0.0);

    // Dynamic pleasant educational color palette
    final branchColors = [
      {'color': '#0EA5E9', 'bg': '#E0F2FE', 'text': '#0369A1'},
      {'color': '#10B981', 'bg': '#D1FAE5', 'text': '#047857'},
      {'color': '#F59E0B', 'bg': '#FEF3C7', 'text': '#B45309'},
      {'color': '#8B5CF6', 'bg': '#EDE9FE', 'text': '#6D28D9'},
      {'color': '#EC4899', 'bg': '#FCE7F3', 'text': '#BE185D'},
    ];
    final palette = branchColors[childCount % branchColors.length];

    final childId = 'node_${_uuid.v4().substring(0, 8)}';
    final newNode = WhiteboardObject(
      id: childId,
      pageId: page.id,
      type: 'rectangle',
      zIndex: page.objects.length + 1,
      data: {
        'x': childX,
        'y': childY,
        'width': 180.0,
        'height': 64.0,
        'color': palette['color'],
        'bgColor': palette['bg'],
        'textColor': palette['text'],
        'text': 'Subtopic ${childCount + 1}',
        'fontSize': 13.0,
        'bold': true,
        'rounded': true,
        'strokeWidth': 2.0,
        'parentNodeId': parentNode.id,
      },
    );

    final connId = 'conn_${_uuid.v4().substring(0, 8)}';
    final newConn = WhiteboardObject(
      id: connId,
      pageId: page.id,
      type: 'connector',
      zIndex: page.objects.length + 2,
      data: {
        'x1': pBounds.right,
        'y1': pBounds.center.dy,
        'x2': childX,
        'y2': childY + 32.0,
        'color': palette['color'],
        'strokeWidth': 2.2,
        'label': 'relates to',
        'startNodeId': parentNode.id,
        'endNodeId': childId,
      },
    );

    // Automatically expand parent if it was collapsed
    if (parentNode.data['collapsed'] == true) {
      final nextParentData = Map<String, dynamic>.from(parentNode.data);
      nextParentData['collapsed'] = false;
      await notifier.updateObject(parentNode.copyWith(data: nextParentData), recordUndo: false);
    }

    await notifier.addMultipleObjects([newNode, newConn]);
    notifier.selectObjects({childId});
    widget.onEditText?.call(newNode, Offset(childX, childY));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(whiteboardProvider);
    final page = s.activePage;
    final notifier = ref.read(whiteboardProvider.notifier);
    final hiddenObjectIds = _getCollapsedHiddenObjectIds(page);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              final delta = signal.scrollDelta.dy;
              final factor = delta < 0 ? 1.08 : 0.92;
              final nextZoom = (s.zoom * factor).clamp(0.25, 4.0);
              // Keep cursor focal point stable while zooming
              final focal = signal.localPosition;
              final logical = (focal - s.panOffset) / s.zoom;
              final nextPan = focal - logical * nextZoom;
              notifier.setZoom(nextZoom);
              notifier.setPanOffset(nextPan);
            }
          },
          onPointerHover: (ev) {
            final l = _toLogical(ev.localPosition, s);
            notifier.emitCursor(l.dx, l.dy);
          },
          onPointerDown: (ev) => _handlePointerDown(ev, s, notifier, viewportSize),
          onPointerMove: (ev) => _handlePointerMove(ev, s, notifier),
          onPointerUp: (ev) => _handlePointerUp(ev, s, notifier),
          child: MouseRegion(
            cursor: _cursorForTool(s.activeTool),
            child: ClipRect(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: viewportSize,
                  painter: _WhiteboardPainter(
                    state: s,
                    page: page,
                    activeStrokePoints: _activePoints,
                    activeStrokePressures: _activePressures,
                    shapeStart: _shapeStart,
                    shapeCurrent: _shapeCurrent,
                    areaEraseRect: _areaEraseRect,
                    repaintTick: _repaintTick,
                    onAsyncImageLoaded: () {
                      if (mounted) setState(() => _repaintTick++);
                    },
                    dragAccumulatedDelta: _dragAccumulatedDelta,
                    draggedObjectIds: _draggedObjectIds,
                    resizingObjectId: _resizingObjectId,
                    resizingRect: _resizingRect,
                    isConnectingNodes: _isConnectingNodes,
                    connectingHoverTargetId: _connectingHoverTargetId,
                    connectingStartPos: _connectingStartPos,
                    connectingCurrentPos: _connectingCurrentPos,
                    hiddenObjectIds: hiddenObjectIds,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  MouseCursor _cursorForTool(WhiteboardTool tool) {
    if (_isConnectingNodes) return SystemMouseCursors.precise;
    if (_isDraggingSelection) return SystemMouseCursors.grabbing;
    if (_isResizingSelection) return SystemMouseCursors.resizeDownRight;

    switch (tool) {
      case WhiteboardTool.pan:
        return SystemMouseCursors.grab;
      case WhiteboardTool.select:
        return SystemMouseCursors.click;
      case WhiteboardTool.text:
        return SystemMouseCursors.text;
      case WhiteboardTool.connector:
        return SystemMouseCursors.precise;
      default:
        return SystemMouseCursors.precise;
    }
  }

  void _handlePointerDown(
    PointerDownEvent ev,
    WhiteboardState s,
    WhiteboardNotifier notifier,
    Size viewportSize,
  ) {
    final logical = _toLogical(ev.localPosition, s);
    final page = s.activePage;

    // Middle mouse button or Pan tool always pans
    if (ev.buttons == kMiddleMouseButton || s.activeTool == WhiteboardTool.pan) {
      _panStartScreen = ev.localPosition;
      _panStartOffset = s.panOffset;
      return;
    }

    if (s.spotlightEnabled) {
      notifier.updateSpotlightCenter(logical);
    }

    if (!s.canCurrentUserEdit && s.activeTool != WhiteboardTool.laser && s.activeTool != WhiteboardTool.select) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Editing disabled or page locked by teacher')),
      );
      return;
    }

    if (page == null) return;

    final hiddenObjectIds = _getCollapsedHiddenObjectIds(page);

    // 1. Mind Map Expand / Collapse Badge Click Check (top priority)
    for (final o in page.objects) {
      if (hiddenObjectIds.contains(o.id)) continue;
      final children = _getChildrenOf(o.id, page);
      if (children.isNotEmpty && !o.isLineBased && !o.isPointBased) {
        final b = o.getBounds();
        final badgeCenter = Offset(b.right + 2, b.center.dy);
        if ((logical - badgeCenter).distance <= 14.0 / s.zoom) {
          final isCollapsed = o.data['collapsed'] == true;
          final nextData = Map<String, dynamic>.from(o.data);
          nextData['collapsed'] = !isCollapsed;
          notifier.updateObject(o.copyWith(data: nextData), recordUndo: true);
          setState(() {});
          return;
        }
      }
    }

    // 2. Select Tool Actions & Mind Map Node Handles
    if (s.activeTool == WhiteboardTool.select) {
      // Check handles on single selected object:
      if (s.selectedObjectIds.length == 1) {
        final selId = s.selectedObjectIds.first;
        final selObj = page.objects.where((o) => o.id == selId).firstOrNull;
        if (selObj != null && !selObj.isLocked) {
          final b = selObj.getBounds();

          // 2a. "+ Branch" Action Pill Click (Spawns linked child node)
          if (!selObj.isLineBased && !selObj.isPointBased) {
            final pillRect = Rect.fromLTWH(
              b.right + 12 / s.zoom,
              b.center.dy - 13 / s.zoom,
              84.0 / s.zoom,
              26.0 / s.zoom,
            );
            if (pillRect.contains(logical)) {
              _addMindMapChildNode(selObj, s, notifier);
              return;
            }

            // 2b. 4 Connection Anchor Ports Click (Drag to link to another node)
            final ports = [
              b.topCenter,
              b.centerRight,
              b.bottomCenter,
              b.centerLeft,
            ];
            for (final port in ports) {
              if ((logical - port).distance <= 12.0 / s.zoom) {
                _isConnectingNodes = true;
                _connectingFromNodeId = selObj.id;
                _connectingStartPos = port;
                _connectingCurrentPos = logical;
                _connectingHoverTargetId = null;
                setState(() {});
                return;
              }
            }
          }

          // 2c. Resize Handle Click (bottom-right)
          final handleCenter = b.bottomRight;
          if ((logical - handleCenter).distance <= 14.0 / s.zoom) {
            _isResizingSelection = true;
            _resizingObjectId = selObj.id;
            _resizingRect = b;
            _lastDragLogical = logical;
            return;
          }
        }
      }

      // Hit test top-most object (ignoring objects hidden by collapsed parents)
      WhiteboardObject? hit;
      for (final o in page.objects.reversed) {
        if (hiddenObjectIds.contains(o.id)) continue;
        if (o.hitTest(logical, tolerance: 10.0 / s.zoom)) {
          hit = o;
          break;
        }
      }

      if (hit != null) {
        if (!s.selectedObjectIds.contains(hit.id)) {
          notifier.selectObjects({hit.id});
          _draggedObjectIds = {hit.id};
        } else {
          _draggedObjectIds = Set.from(s.selectedObjectIds);
        }
        _isDraggingSelection = !hit.isLocked;
        _dragAccumulatedDelta = Offset.zero;
        _lastDragLogical = logical;

        final now = DateTime.now();
        final isDoubleTap = _lastTapTime != null &&
            now.difference(_lastTapTime!).inMilliseconds < 450 &&
            _lastHitObjectId == hit.id;
        _lastTapTime = now;
        _lastHitObjectId = hit.id;

        // Double click shortcut or secondary click for text/equation/shapes
        if (isDoubleTap || ev.buttons == kSecondaryMouseButton) {
          if (hit.type == 'text' ||
              hit.type == 'sticky_note' ||
              hit.type == 'rectangle' ||
              hit.type == 'diamond' ||
              hit.type == 'circle' ||
              hit.type == 'ellipse') {
            widget.onEditText?.call(hit, logical);
          } else if (hit.type == 'equation') {
            widget.onEditEquation?.call(hit, logical);
          }
        }
        setState(() {});
      } else {
        _lastHitObjectId = null;
        _draggedObjectIds.clear();
        _dragAccumulatedDelta = Offset.zero;
        notifier.selectObjects({});
        setState(() {});
      }
      return;
    }

    // Text / Sticky Note / Equation / Image insertion tools
    if (s.activeTool == WhiteboardTool.text) {
      final hit = page.objects.reversed
          .where((o) => !hiddenObjectIds.contains(o.id) && (o.type == 'text' || o.type == 'sticky_note') && o.hitTest(logical))
          .firstOrNull;
      widget.onEditText?.call(hit, logical);
      return;
    }
    if (s.activeTool == WhiteboardTool.stickyNote) {
      final newNote = WhiteboardObject(
        id: 'note_${_uuid.v4().substring(0, 8)}',
        pageId: page.id,
        type: 'sticky_note',
        zIndex: page.objects.length + 1,
        data: {
          'x': logical.dx - 80,
          'y': logical.dy - 60,
          'width': 200.0,
          'height': 140.0,
          'text': 'Key Class Note',
          'bgColor': WhiteboardColorHelper.toHex(s.stickyBgColor),
          'color': '#1E293B',
          'fontSize': 15.0,
        },
      );
      notifier.addObject(newNote);
      widget.onEditText?.call(newNote, logical);
      return;
    }
    if (s.activeTool == WhiteboardTool.equation) {
      final hitEq = page.objects.reversed
          .where((o) => !hiddenObjectIds.contains(o.id) && o.type == 'equation' && o.hitTest(logical))
          .firstOrNull;
      widget.onEditEquation?.call(hitEq, logical);
      return;
    }
    if (s.activeTool == WhiteboardTool.image) {
      widget.onRequestImageUpload?.call();
      return;
    }

    // Freehand Tools (Pen, Pencil, Highlighter, Freeform)
    if (s.activeTool == WhiteboardTool.pen ||
        s.activeTool == WhiteboardTool.pencil ||
        s.activeTool == WhiteboardTool.highlighter ||
        s.activeTool == WhiteboardTool.freeformShape) {
      _activeStrokeId = 'str_${_uuid.v4().substring(0, 8)}';
      _activePoints = [logical];
      _activePressures = [ev.pressure > 0 ? ev.pressure : 1.0];
      notifier.emitStrokePreview(
        _activeStrokeId!,
        _activePoints.map((p) => [p.dx, p.dy]).toList(),
        'stroke.started',
      );
      setState(() {});
      return;
    }

    // Eraser Tool
    if (s.activeTool == WhiteboardTool.eraser) {
      if (s.eraserMode == EraserMode.area) {
        _shapeStart = logical;
        _areaEraseRect = Rect.fromPoints(logical, logical);
        setState(() {});
      } else {
        _eraseAtPoint(logical, s, notifier);
      }
      return;
    }

    // Laser Pointer
    if (s.activeTool == WhiteboardTool.laser) {
      notifier.emitCursor(logical.dx, logical.dy);
      return;
    }

    // Shape / Line / Arrow / Connector / StudentZone Tools
    _shapeStart = logical;
    _shapeCurrent = logical;
    setState(() {});
  }

  void _handlePointerMove(PointerMoveEvent ev, WhiteboardState s, WhiteboardNotifier notifier) {
    if (_panStartScreen != null && _panStartOffset != null) {
      notifier.setPanOffset(_panStartOffset! + (ev.localPosition - _panStartScreen!));
      return;
    }

    final logical = _toLogical(ev.localPosition, s);
    notifier.emitCursor(logical.dx, logical.dy);

    if (s.spotlightEnabled) {
      notifier.updateSpotlightCenter(logical);
    }

    // Dynamic Connection dragging between nodes
    if (_isConnectingNodes) {
      _connectingCurrentPos = logical;
      final page = s.activePage;
      if (page != null) {
        WhiteboardObject? hover;
        for (final o in page.objects.reversed) {
          if (o.id != _connectingFromNodeId && !o.isLineBased && !o.isPointBased && o.hitTest(logical, tolerance: 12.0 / s.zoom)) {
            hover = o;
            break;
          }
        }
        _connectingHoverTargetId = hover?.id;
      }
      setState(() {});
      return;
    }

    // Resizing Selection
    if (_isResizingSelection && _resizingObjectId != null && _lastDragLogical != null) {
      final page = s.activePage;
      final selObj = page?.objects.where((o) => o.id == _resizingObjectId).firstOrNull;
      if (selObj != null) {
        final b = selObj.getBounds();
        _resizingRect = Rect.fromLTWH(
          b.left,
          b.top,
          math.max(28.0, logical.dx - b.left),
          math.max(24.0, logical.dy - b.top),
        );
        setState(() {});
      }
      return;
    }

    // Smooth Dragging Selection (Ephemeral delta accumulation, 60-120 FPS buttery repaint)
    if (_isDraggingSelection && _draggedObjectIds.isNotEmpty && _lastDragLogical != null) {
      final delta = logical - _lastDragLogical!;
      _lastDragLogical = logical;
      _dragAccumulatedDelta += delta;
      setState(() {});
      return;
    }

    if (_activeStrokeId != null) {
      if (_activePoints.isEmpty || (logical - _activePoints.last).distance >= 2.0) {
        _activePoints.add(logical);
        _activePressures.add(ev.pressure > 0 ? ev.pressure : 1.0);
        if (_activePoints.length % 4 == 0) {
          notifier.emitStrokePreview(
            _activeStrokeId!,
            _activePoints.map((p) => [p.dx, p.dy]).toList(),
            'stroke.updated',
          );
        }
        setState(() {});
      }
      return;
    }

    if (s.activeTool == WhiteboardTool.eraser) {
      if (s.eraserMode == EraserMode.area && _shapeStart != null) {
        _areaEraseRect = Rect.fromPoints(_shapeStart!, logical);
        setState(() {});
      } else {
        _eraseAtPoint(logical, s, notifier);
      }
      return;
    }

    if (_shapeStart != null) {
      _shapeCurrent = logical;
      setState(() {});
    }
  }

  void _handlePointerUp(PointerUpEvent ev, WhiteboardState s, WhiteboardNotifier notifier) {
    _panStartScreen = null;
    _panStartOffset = null;
    _lastDragLogical = null;

    final page = s.activePage;
    if (page == null) return;

    // 1. Commit Dynamic Connection between nodes
    if (_isConnectingNodes) {
      if (_connectingHoverTargetId != null && _connectingHoverTargetId != _connectingFromNodeId && _connectingStartPos != null) {
        final targetObj = page.objects.where((o) => o.id == _connectingHoverTargetId).firstOrNull;
        if (targetObj != null) {
          final tb = targetObj.getBounds();
          final ports = [tb.topCenter, tb.centerRight, tb.bottomCenter, tb.centerLeft];
          ports.sort((a, b) => (a - _connectingStartPos!).distance.compareTo((b - _connectingStartPos!).distance));
          final endPort = ports.first;

          final newConn = WhiteboardObject(
            id: 'conn_${_uuid.v4().substring(0, 8)}',
            pageId: page.id,
            type: 'connector',
            zIndex: page.objects.length + 1,
            data: {
              'x1': _connectingStartPos!.dx,
              'y1': _connectingStartPos!.dy,
              'x2': endPort.dx,
              'y2': endPort.dy,
              'color': '#2563EB',
              'strokeWidth': 2.4,
              'label': 'connects to',
              'startNodeId': _connectingFromNodeId,
              'endNodeId': _connectingHoverTargetId,
            },
          );
          notifier.addObject(newConn);
        }
      }
      _isConnectingNodes = false;
      _connectingFromNodeId = null;
      _connectingHoverTargetId = null;
      _connectingStartPos = null;
      _connectingCurrentPos = null;
      setState(() {});
      return;
    }

    // 2. Commit Resizing
    if (_isResizingSelection && _resizingObjectId != null && _resizingRect != null) {
      final selObj = page.objects.where((o) => o.id == _resizingObjectId).firstOrNull;
      if (selObj != null) {
        notifier.updateObject(selObj.resizedTo(_resizingRect!), recordUndo: true);
      }
      _isResizingSelection = false;
      _resizingObjectId = null;
      _resizingRect = null;
      setState(() {});
      return;
    }

    // 3. Commit Smooth Drag & Drop (Batch update nodes AND dynamically linked connectors!)
    if (_isDraggingSelection && _draggedObjectIds.isNotEmpty && _dragAccumulatedDelta != Offset.zero) {
      final delta = _dragAccumulatedDelta;
      final movedObjects = <WhiteboardObject>[];
      for (final id in _draggedObjectIds) {
        final obj = page.objects.where((o) => o.id == id).firstOrNull;
        if (obj != null && !obj.isLocked) {
          movedObjects.add(obj.movedBy(delta.dx, delta.dy));
        }
      }

      // Also dynamically update endpoints of attached connectors!
      for (final obj in page.objects) {
        if (obj.isLineBased && !_draggedObjectIds.contains(obj.id)) {
          final sId = obj.data['startNodeId'] ?? obj.data['fromId'];
          final eId = obj.data['endNodeId'] ?? obj.data['toId'];
          final startMoved = _draggedObjectIds.contains(sId);
          final endMoved = _draggedObjectIds.contains(eId);
          if (startMoved || endMoved) {
            final nextData = Map<String, dynamic>.from(obj.data);
            if (startMoved) {
              nextData['x1'] = ((nextData['x1'] as num?)?.toDouble() ?? 0) + delta.dx;
              nextData['y1'] = ((nextData['y1'] as num?)?.toDouble() ?? 0) + delta.dy;
            }
            if (endMoved) {
              nextData['x2'] = ((nextData['x2'] as num?)?.toDouble() ?? 0) + delta.dx;
              nextData['y2'] = ((nextData['y2'] as num?)?.toDouble() ?? 0) + delta.dy;
            }
            movedObjects.add(obj.copyWith(data: nextData));
          }
        }
      }

      if (movedObjects.isNotEmpty) {
        notifier.updateMultipleObjects(movedObjects, recordUndo: true);
      }
    }
    _isDraggingSelection = false;
    _dragAccumulatedDelta = Offset.zero;
    _draggedObjectIds.clear();

    if (_activeStrokeId != null && _activePoints.isNotEmpty) {
      final pts = List<Offset>.from(_activePoints);
      if (pts.length == 1) {
        pts.add(pts.first + const Offset(1.5, 1.5));
      }
      final typeName = s.activeTool == WhiteboardTool.highlighter
          ? 'highlighter'
          : (s.activeTool == WhiteboardTool.pencil
              ? 'pencil'
              : (s.activeTool == WhiteboardTool.freeformShape ? 'freeform_shape' : 'stroke'));

      final obj = WhiteboardObject(
        id: _activeStrokeId!,
        pageId: page.id,
        type: typeName,
        zIndex: page.objects.length + 1,
        data: {
          'points': pts.map((p) => [double.parse(p.dx.toStringAsFixed(1)), double.parse(p.dy.toStringAsFixed(1))]).toList(),
          'pressures': _activePressures,
          'color': WhiteboardColorHelper.toHex(s.strokeColor),
          if (s.fillColor != null && typeName == 'freeform_shape')
            'bgColor': WhiteboardColorHelper.toHex(s.fillColor!),
          'strokeWidth': typeName == 'highlighter' ? s.strokeWidth * 4.5 : (typeName == 'pencil' ? math.max(1.5, s.strokeWidth * 0.6) : s.strokeWidth),
          'opacity': typeName == 'highlighter' ? 0.38 : s.opacity,
          'strokeStyle': s.strokeStyle,
        },
      );
      _activeStrokeId = null;
      _activePoints = [];
      _activePressures = [];
      notifier.addObject(obj);
      setState(() {});
      return;
    }

    if (s.activeTool == WhiteboardTool.eraser && _areaEraseRect != null) {
      final rect = _areaEraseRect!;
      _areaEraseRect = null;
      _shapeStart = null;
      notifier.eraseAreaRect(rect);
      setState(() {});
      return;
    }

    if (_shapeStart != null && _shapeCurrent != null) {
      final a = _shapeStart!;
      final b = _shapeCurrent!;
      _shapeStart = null;
      _shapeCurrent = null;
      if ((b - a).distance < 6.0) {
        setState(() {});
        return;
      }

      final rect = Rect.fromPoints(a, b);
      String? otype;
      final data = <String, dynamic>{
        'color': WhiteboardColorHelper.toHex(s.strokeColor),
        if (s.fillColor != null) 'bgColor': WhiteboardColorHelper.toHex(s.fillColor!),
        'strokeWidth': s.strokeWidth,
        'opacity': s.opacity,
        'rounded': s.roundedCorners,
      };

      switch (s.activeTool) {
        case WhiteboardTool.line:
        case WhiteboardTool.arrow:
        case WhiteboardTool.doubleArrow:
        case WhiteboardTool.curvedLine:
        case WhiteboardTool.connector:
        case WhiteboardTool.measurement:
          otype = {
            WhiteboardTool.line: 'line',
            WhiteboardTool.arrow: 'arrow',
            WhiteboardTool.doubleArrow: 'double_arrow',
            WhiteboardTool.curvedLine: 'curved_line',
            WhiteboardTool.connector: 'connector',
            WhiteboardTool.measurement: 'measurement',
          }[s.activeTool];
          data['x1'] = a.dx;
          data['y1'] = a.dy;
          data['x2'] = b.dx;
          data['y2'] = b.dy;
          if (s.activeTool == WhiteboardTool.connector) {
            data['label'] = 'connects to';
            // Auto-detect attached nodes if drawn on nodes
            for (final o in page.objects.reversed) {
              if (!o.isLineBased && !o.isPointBased) {
                final ob = o.getBounds().inflate(8);
                if (ob.contains(a) && data['startNodeId'] == null) {
                  data['startNodeId'] = o.id;
                }
                if (ob.contains(b) && data['endNodeId'] == null) {
                  data['endNodeId'] = o.id;
                }
              }
            }
          }
          break;
        case WhiteboardTool.rectangle:
        case WhiteboardTool.circle:
        case WhiteboardTool.ellipse:
        case WhiteboardTool.triangle:
        case WhiteboardTool.polygon:
        case WhiteboardTool.star:
        case WhiteboardTool.studentZone:
          otype = {
            WhiteboardTool.rectangle: 'rectangle',
            WhiteboardTool.circle: 'circle',
            WhiteboardTool.ellipse: 'ellipse',
            WhiteboardTool.triangle: 'triangle',
            WhiteboardTool.polygon: 'polygon',
            WhiteboardTool.star: 'star',
            WhiteboardTool.studentZone: 'student_zone',
          }[s.activeTool];
          data['x'] = rect.left;
          data['y'] = rect.top;
          data['width'] = s.activeTool == WhiteboardTool.circle ? math.max(rect.width, rect.height) : rect.width;
          data['height'] = s.activeTool == WhiteboardTool.circle ? math.max(rect.width, rect.height) : rect.height;
          if (s.activeTool == WhiteboardTool.studentZone) {
            data['label'] = 'Student Work Zone';
            data['color'] = '#2563EB';
            data['bgColor'] = '#EFF6FF';
          }
          break;
        default:
          break;
      }

      if (otype != null) {
        final obj = WhiteboardObject(
          id: 'shp_${_uuid.v4().substring(0, 8)}',
          pageId: page.id,
          type: otype,
          zIndex: page.objects.length + 1,
          data: data,
        );
        notifier.addObject(obj);
      }
      setState(() {});
    }
  }

  void _eraseAtPoint(Offset logical, WhiteboardState s, WhiteboardNotifier notifier) {
    final page = s.activePage;
    if (page == null) return;
    for (final obj in page.objects.reversed) {
      if (obj.isLocked) continue;
      if (s.eraserMode == EraserMode.stroke && !obj.isPointBased) continue;
      if (obj.hitTest(logical, tolerance: s.eraserSize / s.zoom)) {
        notifier.deleteObjectById(obj.id);
        break;
      }
    }
  }
}

class _WhiteboardPainter extends CustomPainter {
  final WhiteboardState state;
  final WhiteboardPage? page;
  final List<Offset> activeStrokePoints;
  final List<double> activeStrokePressures;
  final Offset? shapeStart;
  final Offset? shapeCurrent;
  final Rect? areaEraseRect;
  final int repaintTick;
  final VoidCallback onAsyncImageLoaded;
  // Ephemeral smooth drag, resize, connection & mind-map states
  final Offset dragAccumulatedDelta;
  final Set<String> draggedObjectIds;
  final String? resizingObjectId;
  final Rect? resizingRect;
  final bool isConnectingNodes;
  final String? connectingHoverTargetId;
  final Offset? connectingStartPos;
  final Offset? connectingCurrentPos;
  final Set<String> hiddenObjectIds;

  _WhiteboardPainter({
    required this.state,
    required this.page,
    required this.activeStrokePoints,
    required this.activeStrokePressures,
    required this.shapeStart,
    required this.shapeCurrent,
    required this.areaEraseRect,
    required this.repaintTick,
    required this.onAsyncImageLoaded,
    required this.dragAccumulatedDelta,
    required this.draggedObjectIds,
    required this.resizingObjectId,
    required this.resizingRect,
    required this.isConnectingNodes,
    required this.connectingHoverTargetId,
    required this.connectingStartPos,
    required this.connectingCurrentPos,
    required this.hiddenObjectIds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgType = page?.backgroundType ?? WhiteboardBackgroundType.plain;
    _drawBackground(canvas, size, bgType);

    canvas.save();
    canvas.translate(state.panOffset.dx, state.panOffset.dy);
    canvas.scale(state.zoom);

    // Viewport culling rect in logical coordinates
    final visibleLogical = Rect.fromLTWH(
      -state.panOffset.dx / state.zoom,
      -state.panOffset.dy / state.zoom,
      size.width / state.zoom,
      size.height / state.zoom,
    ).inflate(40);

    // Draw saved page objects (filtering collapsed subtrees and shifting live dragged/resized objects)
    if (page != null) {
      final objs = List<WhiteboardObject>.from(page!.objects)
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      for (final obj in objs) {
        if (hiddenObjectIds.contains(obj.id)) continue;

        WhiteboardObject renderedObj = obj;
        if (draggedObjectIds.contains(obj.id) && dragAccumulatedDelta != Offset.zero) {
          renderedObj = obj.movedBy(dragAccumulatedDelta.dx, dragAccumulatedDelta.dy);
        } else if (resizingObjectId == obj.id && resizingRect != null) {
          renderedObj = obj.resizedTo(resizingRect!);
        } else if (obj.isLineBased && dragAccumulatedDelta != Offset.zero) {
          final sId = obj.data['startNodeId'] ?? obj.data['fromId'];
          final eId = obj.data['endNodeId'] ?? obj.data['toId'];
          final sMoved = draggedObjectIds.contains(sId);
          final eMoved = draggedObjectIds.contains(eId);
          if (sMoved || eMoved) {
            final nextData = Map<String, dynamic>.from(obj.data);
            if (sMoved) {
              nextData['x1'] = ((nextData['x1'] as num?)?.toDouble() ?? 0) + dragAccumulatedDelta.dx;
              nextData['y1'] = ((nextData['y1'] as num?)?.toDouble() ?? 0) + dragAccumulatedDelta.dy;
            }
            if (eMoved) {
              nextData['x2'] = ((nextData['x2'] as num?)?.toDouble() ?? 0) + dragAccumulatedDelta.dx;
              nextData['y2'] = ((nextData['y2'] as num?)?.toDouble() ?? 0) + dragAccumulatedDelta.dy;
            }
            renderedObj = obj.copyWith(data: nextData);
          }
        }

        if (!renderedObj.getBounds().overlaps(visibleLogical)) continue;
        _drawObject(canvas, renderedObj, onAsyncImageLoaded);
      }
    }

    // Draw remote preview strokes
    for (final preview in state.remotePreviewStrokes.values) {
      if (preview.pageId == page?.id) {
        _drawObject(canvas, preview, onAsyncImageLoaded);
      }
    }

    // Draw active local stroke
    if (activeStrokePoints.isNotEmpty) {
      final tempObj = WhiteboardObject(
        id: 'active',
        pageId: page?.id ?? '',
        type: state.activeTool == WhiteboardTool.highlighter
            ? 'highlighter'
            : (state.activeTool == WhiteboardTool.pencil
                ? 'pencil'
                : (state.activeTool == WhiteboardTool.freeformShape ? 'freeform_shape' : 'stroke')),
        data: {
          'points': activeStrokePoints.map((p) => [p.dx, p.dy]).toList(),
          'pressures': activeStrokePressures,
          'color': WhiteboardColorHelper.toHex(state.strokeColor),
          'strokeWidth': state.activeTool == WhiteboardTool.highlighter
              ? state.strokeWidth * 4.5
              : state.strokeWidth,
          'opacity': state.activeTool == WhiteboardTool.highlighter ? 0.38 : state.opacity,
          'strokeStyle': state.strokeStyle,
        },
      );
      _drawObject(canvas, tempObj, onAsyncImageLoaded);
    }

    // Draw active shape preview
    if (shapeStart != null && shapeCurrent != null && state.activeTool != WhiteboardTool.eraser) {
      final rect = Rect.fromPoints(shapeStart!, shapeCurrent!);
      final previewType = {
        WhiteboardTool.line: 'line',
        WhiteboardTool.arrow: 'arrow',
        WhiteboardTool.doubleArrow: 'double_arrow',
        WhiteboardTool.curvedLine: 'curved_line',
        WhiteboardTool.connector: 'connector',
        WhiteboardTool.measurement: 'measurement',
        WhiteboardTool.rectangle: 'rectangle',
        WhiteboardTool.circle: 'circle',
        WhiteboardTool.ellipse: 'ellipse',
        WhiteboardTool.triangle: 'triangle',
        WhiteboardTool.polygon: 'polygon',
        WhiteboardTool.star: 'star',
        WhiteboardTool.studentZone: 'student_zone',
      }[state.activeTool];
      if (previewType != null) {
        final previewObj = WhiteboardObject(
          id: 'shape_preview',
          pageId: page?.id ?? '',
          type: previewType,
          data: {
            'x1': shapeStart!.dx,
            'y1': shapeStart!.dy,
            'x2': shapeCurrent!.dx,
            'y2': shapeCurrent!.dy,
            'x': rect.left,
            'y': rect.top,
            'width': state.activeTool == WhiteboardTool.circle ? math.max(rect.width, rect.height) : rect.width,
            'height': state.activeTool == WhiteboardTool.circle ? math.max(rect.width, rect.height) : rect.height,
            'color': WhiteboardColorHelper.toHex(state.strokeColor),
            if (state.fillColor != null) 'bgColor': WhiteboardColorHelper.toHex(state.fillColor!),
            'strokeWidth': state.strokeWidth,
            'opacity': 0.7,
            'rounded': state.roundedCorners,
          },
        );
        _drawObject(canvas, previewObj, onAsyncImageLoaded);
      }
    }

    // Area eraser marquee
    if (areaEraseRect != null) {
      final p = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.14)
        ..style = PaintingStyle.fill;
      final b = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(areaEraseRect!, p);
      canvas.drawRect(areaEraseRect!, b);
    }

    // Selection highlights, resize handles, 4 connection ports & "+ Branch" pill
    if (page != null && state.selectedObjectIds.isNotEmpty) {
      for (final id in state.selectedObjectIds) {
        if (hiddenObjectIds.contains(id)) continue;
        final sel = page!.objects.where((o) => o.id == id).firstOrNull;
        if (sel != null) {
          var bounds = sel.getBounds();
          if (draggedObjectIds.contains(sel.id) && dragAccumulatedDelta != Offset.zero) {
            bounds = bounds.shift(dragAccumulatedDelta);
          } else if (resizingObjectId == sel.id && resizingRect != null) {
            bounds = resizingRect!;
          }

          final selPaint = Paint()
            ..color = const Color(0xFF2563EB)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 / state.zoom;
          canvas.drawRect(bounds, selPaint);

          // Resize handle (bottom-right)
          if (!sel.isLocked && state.selectedObjectIds.length == 1) {
            final handle = bounds.bottomRight;
            canvas.drawCircle(handle, 6.0 / state.zoom, Paint()..color = Colors.white);
            canvas.drawCircle(handle, 6.0 / state.zoom, selPaint);

            // If it's a node (box/note/shape), show 4 connection anchor ports & "+ Branch" action pill
            if (!sel.isLineBased && !sel.isPointBased) {
              // 4 Connection Anchor Ports
              final portPositions = [
                bounds.topCenter,
                bounds.centerRight,
                bounds.bottomCenter,
                bounds.centerLeft,
              ];
              for (final pos in portPositions) {
                canvas.drawCircle(pos, 5.0 / state.zoom, Paint()..color = Colors.white);
                canvas.drawCircle(
                  pos,
                  5.0 / state.zoom,
                  Paint()
                    ..color = const Color(0xFF2563EB)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.8 / state.zoom,
                );
              }

              // "+ Branch" action pill
              final pillLeft = bounds.right + 12 / state.zoom;
              final pillTop = bounds.center.dy - 13 / state.zoom;
              final pillW = 84.0 / state.zoom;
              final pillH = 26.0 / state.zoom;
              final branchPill = RRect.fromRectAndRadius(
                Rect.fromLTWH(pillLeft, pillTop, pillW, pillH),
                Radius.circular(13.0 / state.zoom),
              );
              canvas.drawRRect(branchPill.shift(Offset(0, 1.8 / state.zoom)), Paint()..color = Colors.black.withValues(alpha: 0.18));
              canvas.drawRRect(branchPill, Paint()..color = const Color(0xFF2563EB));
              canvas.drawRRect(
                branchPill,
                Paint()
                  ..color = const Color(0xFF93C5FD)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.0 / state.zoom,
              );
              final tp = TextPainter(
                text: TextSpan(
                  text: '+ Branch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.0 / state.zoom,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              tp.paint(canvas, Offset(pillLeft + (pillW - tp.width) / 2, pillTop + (pillH - tp.height) / 2));
            }
          }
        }
      }
    }

    // Draw Mind Map Expand / Collapse Badges for all nodes with children
    if (page != null) {
      for (final obj in page!.objects) {
        if (hiddenObjectIds.contains(obj.id)) continue;
        final children = _WhiteboardCanvasEngineState._getChildrenOf(obj.id, page!);
        if (children.isNotEmpty && !obj.isLineBased && !obj.isPointBased) {
          var b = obj.getBounds();
          if (draggedObjectIds.contains(obj.id) && dragAccumulatedDelta != Offset.zero) {
            b = b.shift(dragAccumulatedDelta);
          }
          final badgeCenter = Offset(b.right + 2, b.center.dy);
          final isCollapsed = obj.data['collapsed'] == true;
          if (isCollapsed) {
            final count = children.length;
            final text = '+$count';
            final tp = TextPainter(
              text: TextSpan(
                text: text,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            final pillW = math.max(22.0, tp.width + 10);
            final pillRect = RRect.fromRectAndRadius(
              Rect.fromCenter(center: badgeCenter, width: pillW, height: 20),
              const Radius.circular(10),
            );
            canvas.drawRRect(pillRect.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.2));
            canvas.drawRRect(pillRect, Paint()..color = const Color(0xFF4F46E5));
            canvas.drawRRect(pillRect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.4);
            tp.paint(canvas, badgeCenter - Offset(tp.width / 2, tp.height / 2));
          } else {
            canvas.drawCircle(badgeCenter, 8.5, Paint()..color = Colors.white);
            canvas.drawCircle(
              badgeCenter,
              8.5,
              Paint()
                ..color = const Color(0xFF64748B)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2,
            );
            canvas.drawLine(
              badgeCenter - const Offset(4.5, 0),
              badgeCenter + const Offset(4.5, 0),
              Paint()
                ..color = const Color(0xFF334155)
                ..strokeWidth = 1.8
                ..strokeCap = StrokeCap.round,
            );
          }
        }
      }
    }

    // Active Connection Line Preview (Dragging connector between nodes)
    if (connectingStartPos != null && connectingCurrentPos != null) {
      final a = connectingStartPos!;
      final b = connectingCurrentPos!;
      final connPaint = Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 2.4 / state.zoom
        ..strokeCap = StrokeCap.round;

      final ctrl = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 35);
      final p = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      canvas.drawPath(p, connPaint);
      _drawArrowHead(canvas, ctrl, b, const Color(0xFF2563EB), 2.4 / state.zoom);

      // Target hover glow
      if (connectingHoverTargetId != null && page != null) {
        final tgt = page!.objects.where((o) => o.id == connectingHoverTargetId).firstOrNull;
        if (tgt != null) {
          final tb = tgt.getBounds().inflate(4);
          final tgtPaint = Paint()
            ..color = const Color(0xFF10B981)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 / state.zoom;
          canvas.drawRRect(RRect.fromRectAndRadius(tb, const Radius.circular(8)), tgtPaint);
        }
      }
    }

    // Ephemeral laser pointer trail
    for (final lp in state.laserPoints) {
      final ageMs = DateTime.now().difference(lp.createdAt).inMilliseconds;
      final fade = (1.0 - ageMs / 1600.0).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      canvas.drawCircle(
        lp.position,
        10.0 * fade,
        Paint()..color = lp.color.withValues(alpha: 0.28 * fade),
      );
      canvas.drawCircle(
        lp.position,
        4.5,
        Paint()..color = lp.color.withValues(alpha: fade),
      );
    }

    // Remote collaborator live cursors
    for (final c in state.remoteCursors.values) {
      if (c.pageId != null && c.pageId != page?.id) continue;
      if (DateTime.now().difference(c.updatedAt).inSeconds > 15) continue;
      final pos = Offset(c.x, c.y);
      final ptrPath = Path()
        ..moveTo(pos.dx, pos.dy)
        ..lineTo(pos.dx + 12, pos.dy + 9)
        ..lineTo(pos.dx + 5, pos.dy + 11)
        ..close();
      canvas.drawPath(ptrPath, Paint()..color = c.color);
      final tp = TextPainter(
        text: TextSpan(
          text: c.name,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(pos.dx + 12, pos.dy + 12, tp.width + 10, tp.height + 4),
        const Radius.circular(6),
      );
      canvas.drawRRect(pill, Paint()..color = c.color);
      tp.paint(canvas, Offset(pos.dx + 17, pos.dy + 14));
    }

    // Teacher Spotlight overlay
    if (state.spotlightEnabled) {
      final overlayPath = Path()
        ..addRect(visibleLogical)
        ..addOval(Rect.fromCircle(center: state.spotlightCenter, radius: 130))
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(overlayPath, Paint()..color = Colors.black.withValues(alpha: 0.48));
      canvas.drawCircle(
        state.spotlightCenter,
        130,
        Paint()
          ..color = const Color(0xFF60A5FA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    canvas.restore();
  }

  static void _drawBackground(Canvas canvas, Size size, WhiteboardBackgroundType bgType) {
    final isDark = bgType == WhiteboardBackgroundType.darkGrid;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white,
    );

    if (bgType == WhiteboardBackgroundType.lightGrid ||
        bgType == WhiteboardBackgroundType.darkGrid ||
        bgType == WhiteboardBackgroundType.graph ||
        bgType == WhiteboardBackgroundType.engineering) {
      final step = (bgType == WhiteboardBackgroundType.graph || bgType == WhiteboardBackgroundType.engineering)
          ? 20.0
          : 32.0;
      final gridPaint = Paint()
        ..color = isDark
            ? const Color(0xFF1E293B)
            : (bgType == WhiteboardBackgroundType.graph ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0))
        ..strokeWidth = 1.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    } else if (bgType == WhiteboardBackgroundType.dotted) {
      final dotPaint = Paint()..color = const Color(0xFFCBD5E1);
      for (double x = 20; x < size.width; x += 24) {
        for (double y = 20; y < size.height; y += 24) {
          canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
        }
      }
    } else if (bgType == WhiteboardBackgroundType.ruled) {
      final rulePaint = Paint()..color = const Color(0xFFDBEAFE);
      for (double y = 40; y < size.height; y += 28) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
      }
      canvas.drawLine(const Offset(64, 0), Offset(64, size.height), Paint()..color = const Color(0xFFFCA5A5));
    } else if (bgType == WhiteboardBackgroundType.music) {
      final staffPaint = Paint()..color = const Color(0xFF94A3B8);
      for (double y = 50; y < size.height - 40; y += 76) {
        for (int line = 0; line < 5; line++) {
          canvas.drawLine(Offset(24, y + line * 9), Offset(size.width - 24, y + line * 9), staffPaint);
        }
      }
    }
  }

  static void _drawObject(Canvas canvas, WhiteboardObject obj, VoidCallback onAsyncImageLoaded) {
    final data = obj.data;
    final col = obj.color.withValues(alpha: obj.opacity);
    final strokePaint = Paint()
      ..color = col
      ..strokeWidth = obj.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (obj.isPointBased) {
      final pts = obj.points;
      if (pts.isEmpty) return;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        if (i + 1 < pts.length) {
          final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
          path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
        } else {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
      }
      if (obj.type == 'freeform_shape') {
        path.close();
        if (obj.bgColor != null) {
          canvas.drawPath(
            path,
            Paint()
              ..color = obj.bgColor!.withValues(alpha: 0.35)
              ..style = PaintingStyle.fill,
          );
        }
      }
      canvas.drawPath(path, strokePaint);
      return;
    }

    if (obj.isLineBased) {
      final a = Offset((data['x1'] as num?)?.toDouble() ?? 0, (data['y1'] as num?)?.toDouble() ?? 0);
      final b = Offset((data['x2'] as num?)?.toDouble() ?? 0, (data['y2'] as num?)?.toDouble() ?? 0);
      if (obj.type == 'curved_line' || obj.type == 'connector') {
        final ctrl = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 45);
        final p = Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
        canvas.drawPath(p, strokePaint);
      } else {
        canvas.drawLine(a, b, strokePaint);
      }
      if (obj.type == 'arrow' || obj.type == 'double_arrow' || obj.type == 'connector') {
        _drawArrowHead(canvas, a, b, col, obj.strokeWidth);
        if (obj.type == 'double_arrow') {
          _drawArrowHead(canvas, b, a, col, obj.strokeWidth);
        }
      }
      if (obj.type == 'measurement') {
        final dist = (b - a).distance;
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: '${dist.toStringAsFixed(0)} px',
            style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.bold, backgroundColor: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, mid - Offset(tp.width / 2, 16));
      } else if (data['label'] != null || data['text'] != null) {
        final labelStr = (data['label'] ?? data['text']).toString();
        if (labelStr.isNotEmpty) {
          final mid = (obj.type == 'curved_line' || obj.type == 'connector')
              ? Offset((a.dx + b.dx) / 2, (math.min(a.dy, b.dy) - 45 + (a.dy + b.dy) / 2) / 2)
              : Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
          final tp = TextPainter(
            text: TextSpan(
              text: labelStr,
              style: TextStyle(
                color: col,
                fontSize: (data['fontSize'] as num?)?.toDouble() ?? 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final badgeRect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: mid, width: tp.width + 12, height: tp.height + 6),
            const Radius.circular(4),
          );
          canvas.drawRRect(badgeRect, Paint()..color = Colors.white);
          canvas.drawRRect(badgeRect, Paint()..color = col.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.2);
          tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
        }
      }
      return;
    }

    final bounds = obj.getBounds();

    if (obj.type == 'rectangle' || obj.type == 'student_zone') {
      final rounded = data['rounded'] != false;
      final rrect = RRect.fromRectAndRadius(bounds, Radius.circular(rounded ? 8 : 0));
      if (obj.bgColor != null) {
        canvas.drawRRect(rrect, Paint()..color = obj.bgColor!.withValues(alpha: obj.type == 'student_zone' ? 0.55 : obj.opacity));
      }
      canvas.drawRRect(rrect, strokePaint);
      if (obj.type == 'student_zone' && data['label'] != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: data['label'].toString(),
            style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bounds.width - 12);
        tp.paint(canvas, bounds.topLeft + const Offset(8, 6));
      } else if (data['text'] != null || data['label'] != null) {
        final textStr = (data['text'] ?? data['label']).toString();
        final textCol = data['textColor'] != null
            ? WhiteboardColorHelper.parse(data['textColor'].toString(), fallback: col)
            : col;
        final tp = TextPainter(
          text: TextSpan(
            text: textStr,
            style: TextStyle(
              color: textCol,
              fontSize: (data['fontSize'] as num?)?.toDouble() ?? 14,
              fontWeight: data['bold'] == true ? FontWeight.bold : FontWeight.w600,
              height: 1.3,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(20.0, bounds.width - 16));
        final toffset = Offset(
          bounds.left + (bounds.width - tp.width) / 2,
          bounds.top + (bounds.height - tp.height) / 2,
        );
        tp.paint(canvas, toffset);
      }
      return;
    }

    if (obj.type == 'diamond') {
      final p = Path()
        ..moveTo(bounds.center.dx, bounds.top)
        ..lineTo(bounds.right, bounds.center.dy)
        ..lineTo(bounds.center.dx, bounds.bottom)
        ..lineTo(bounds.left, bounds.center.dy)
        ..close();
      if (obj.bgColor != null) {
        canvas.drawPath(p, Paint()..color = obj.bgColor!.withValues(alpha: obj.opacity));
      }
      canvas.drawPath(p, strokePaint);
      if (data['text'] != null || data['label'] != null) {
        final textStr = (data['text'] ?? data['label']).toString();
        final textCol = data['textColor'] != null
            ? WhiteboardColorHelper.parse(data['textColor'].toString(), fallback: col)
            : col;
        final tp = TextPainter(
          text: TextSpan(
            text: textStr,
            style: TextStyle(
              color: textCol,
              fontSize: (data['fontSize'] as num?)?.toDouble() ?? 12,
              fontWeight: data['bold'] == true ? FontWeight.bold : FontWeight.w600,
              height: 1.25,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(20.0, bounds.width * 0.7));
        final toffset = Offset(
          bounds.left + (bounds.width - tp.width) / 2,
          bounds.top + (bounds.height - tp.height) / 2,
        );
        tp.paint(canvas, toffset);
      }
      return;
    }

    if (obj.type == 'circle' || obj.type == 'ellipse') {
      if (obj.bgColor != null) {
        canvas.drawOval(bounds, Paint()..color = obj.bgColor!.withValues(alpha: obj.opacity));
      }
      canvas.drawOval(bounds, strokePaint);
      if (data['text'] != null || data['label'] != null) {
        final textStr = (data['text'] ?? data['label']).toString();
        final textCol = data['textColor'] != null
            ? WhiteboardColorHelper.parse(data['textColor'].toString(), fallback: col)
            : col;
        final tp = TextPainter(
          text: TextSpan(
            text: textStr,
            style: TextStyle(
              color: textCol,
              fontSize: (data['fontSize'] as num?)?.toDouble() ?? 12,
              fontWeight: data['bold'] == true ? FontWeight.bold : FontWeight.w600,
              height: 1.25,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(20.0, bounds.width * 0.75));
        final toffset = Offset(
          bounds.left + (bounds.width - tp.width) / 2,
          bounds.top + (bounds.height - tp.height) / 2,
        );
        tp.paint(canvas, toffset);
      }
      return;
    }

    if (obj.type == 'triangle' || obj.type == 'polygon' || obj.type == 'star') {
      final p = Path();
      if (obj.type == 'triangle') {
        p.moveTo(bounds.center.dx, bounds.top);
        p.lineTo(bounds.left, bounds.bottom);
        p.lineTo(bounds.right, bounds.bottom);
      } else {
        final center = bounds.center;
        final radius = math.min(bounds.width, bounds.height) / 2;
        final n = obj.type == 'star' ? 10 : 6;
        for (int i = 0; i < n; i++) {
          final ang = -math.pi / 2 + i * (2 * math.pi / n);
          final r = (obj.type == 'polygon' || i.isEven) ? radius : radius * 0.45;
          final pt = Offset(center.dx + r * math.cos(ang), center.dy + r * math.sin(ang));
          if (i == 0) {
            p.moveTo(pt.dx, pt.dy);
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        }
      }
      p.close();
      if (obj.bgColor != null) {
        canvas.drawPath(p, Paint()..color = obj.bgColor!.withValues(alpha: obj.opacity));
      }
      canvas.drawPath(p, strokePaint);
      return;
    }

    if (obj.type == 'sticky_note') {
      final bg = obj.bgColor ?? const Color(0xFFFEF3C7);
      final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(8));
      canvas.drawRRect(rrect.shift(const Offset(2, 3)), Paint()..color = Colors.black.withValues(alpha: 0.08));
      canvas.drawRRect(rrect, Paint()..color = bg);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFF59E0B).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: (data['text'] ?? '').toString(),
          style: TextStyle(
            color: col,
            fontSize: (data['fontSize'] as num?)?.toDouble() ?? 15,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: bounds.width - 20);
      tp.paint(canvas, bounds.topLeft + const Offset(10, 10));
      return;
    }

    if (obj.type == 'equation') {
      final bg = obj.bgColor ?? const Color(0xFFE0F2FE);
      final bd = obj.borderColor ?? const Color(0xFF93C5FD);
      final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(8));
      canvas.drawRRect(rrect, Paint()..color = bg);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = bd
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      _paintStructuredMath(canvas, bounds, data, col);
      return;
    }

    if (obj.type == 'text') {
      if (obj.bgColor != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(6)),
          Paint()..color = obj.bgColor!,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: (data['text'] ?? '').toString(),
          style: TextStyle(
            color: col,
            fontSize: (data['fontSize'] as num?)?.toDouble() ?? 18,
            fontWeight: data['bold'] == true ? FontWeight.bold : FontWeight.w500,
            fontStyle: data['italic'] == true ? FontStyle.italic : FontStyle.normal,
            decoration: data['underline'] == true ? TextDecoration.underline : TextDecoration.none,
            height: 1.4,
          ),
        ),
        textAlign: data['align'] == 'center'
            ? TextAlign.center
            : (data['align'] == 'right' ? TextAlign.right : TextAlign.left),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: bounds.width - 8);
      tp.paint(canvas, bounds.topLeft + const Offset(4, 4));
      return;
    }

    if (obj.type == 'image' || obj.type == 'pdf_page') {
      final contentUrl = (data['content_url'] ?? '').toString();
      final uiImg = obj.type == 'image' ? WhiteboardImageCache.getOrLoad(contentUrl, onAsyncImageLoaded) : null;
      final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(8));
      if (uiImg != null) {
        canvas.save();
        canvas.clipRRect(rrect);
        paintImage(canvas: canvas, rect: bounds, image: uiImg, fit: BoxFit.contain);
        canvas.restore();
      } else {
        canvas.drawRRect(rrect, Paint()..color = const Color(0xFFF8FAFC));
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        final label = obj.type == 'pdf_page'
            ? 'PDF Document: ${data['file_name'] ?? 'Slide'} (Page ${data['pdf_page_number'] ?? 1})'
            : 'Loading image: ${data['file_name'] ?? ''}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bounds.width - 24);
        tp.paint(canvas, bounds.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  static void _paintStructuredMath(Canvas canvas, Rect bounds, Map<String, dynamic> data, Color color) {
    final latex = (data['latex'] ?? '').toString();
    final display = (data['display'] ?? latex).toString();
    final fontSize = (data['fontSize'] as num?)?.toDouble() ?? 20.0;

    // Render true stacked fraction if quadratic formula or \frac is present
    final fracMatch = RegExp(r'^(.*?)=\s*\\frac\{(.+?)\}\{(.+?)\}$').firstMatch(latex);
    if (fracMatch != null) {
      final lhs = '${fracMatch.group(1)!.trim()} = ';
      final numText = fracMatch.group(2)!
          .replaceAll(r'\pm', '±')
          .replaceAll(r'\sqrt{', '√(')
          .replaceAll('}', ')')
          .replaceAll('^2', '²');
      final denText = fracMatch.group(3)!;

      final lhsTp = TextPainter(
        text: TextSpan(
          text: lhs,
          style: TextStyle(color: color, fontSize: fontSize, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final numTp = TextPainter(
        text: TextSpan(
          text: numText,
          style: TextStyle(color: color, fontSize: fontSize * 0.85, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final denTp = TextPainter(
        text: TextSpan(
          text: denText,
          style: TextStyle(color: color, fontSize: fontSize * 0.85, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final barW = math.max(numTp.width, denTp.width) + 16;
      final totalW = lhsTp.width + barW;
      final startX = bounds.center.dx - totalW / 2;
      final cy = bounds.center.dy;

      lhsTp.paint(canvas, Offset(startX, cy - lhsTp.height / 2));
      numTp.paint(canvas, Offset(startX + lhsTp.width + (barW - numTp.width) / 2, cy - numTp.height - 4));
      canvas.drawLine(
        Offset(startX + lhsTp.width, cy),
        Offset(startX + lhsTp.width + barW, cy),
        Paint()
          ..color = color
          ..strokeWidth = 1.6,
      );
      denTp.paint(canvas, Offset(startX + lhsTp.width + (barW - denTp.width) / 2, cy + 4));
      return;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: display,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: bounds.width - 14);
    tp.paint(canvas, bounds.center - Offset(tp.width / 2, tp.height / 2));
  }

  static void _drawArrowHead(Canvas canvas, Offset from, Offset to, Color color, double strokeWidth) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final len = math.max(11.0, strokeWidth * 3.5);
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      to,
      Offset(to.dx - len * math.cos(angle - math.pi / 6), to.dy - len * math.sin(angle - math.pi / 6)),
      p,
    );
    canvas.drawLine(
      to,
      Offset(to.dx - len * math.cos(angle + math.pi / 6), to.dy - len * math.sin(angle + math.pi / 6)),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.page != page ||
        oldDelegate.activeStrokePoints.length != activeStrokePoints.length ||
        oldDelegate.shapeCurrent != shapeCurrent ||
        oldDelegate.areaEraseRect != areaEraseRect ||
        oldDelegate.repaintTick != repaintTick ||
        oldDelegate.dragAccumulatedDelta != dragAccumulatedDelta ||
        oldDelegate.draggedObjectIds.length != draggedObjectIds.length ||
        oldDelegate.resizingRect != resizingRect ||
        oldDelegate.isConnectingNodes != isConnectingNodes ||
        oldDelegate.connectingCurrentPos != connectingCurrentPos ||
        oldDelegate.connectingHoverTargetId != connectingHoverTargetId ||
        oldDelegate.hiddenObjectIds.length != hiddenObjectIds.length;
  }
}

/// Miniature preview painter used in the "Boards (N)" left thumbnail strip.
class WhiteboardThumbnailPainter extends CustomPainter {
  final WhiteboardPage page;

  const WhiteboardThumbnailPainter({required this.page});

  @override
  void paint(Canvas canvas, Size size) {
    _WhiteboardPainter._drawBackground(canvas, size, page.backgroundType);
    canvas.save();
    final scale = math.min(size.width / 960.0, size.height / 540.0);
    canvas.scale(scale);
    for (final obj in page.objects) {
      _WhiteboardPainter._drawObject(canvas, obj, () {});
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WhiteboardThumbnailPainter oldDelegate) => oldDelegate.page != page;
}
