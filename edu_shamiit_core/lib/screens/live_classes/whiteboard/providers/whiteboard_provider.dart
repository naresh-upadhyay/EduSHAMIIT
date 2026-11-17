import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/whiteboard_models.dart';
import '../services/whiteboard_api_service.dart';
import '../services/whiteboard_ws_service.dart';

const _uuid = Uuid();

class WhiteboardState {
  final WhiteboardDocument? document;
  final List<Map<String, dynamic>> sessionBoards;
  final List<WhiteboardTemplateItem> templates;
  final String? activePageId;
  final bool isLoading;
  final bool wsConnected;
  final WhiteboardSaveState saveState;
  final String? statusMessage;

  // Tool & Properties State
  final WhiteboardTool activeTool;
  final EraserMode eraserMode;
  final double eraserSize;
  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  final double opacity;
  final String strokeStyle; // 'solid', 'dashed', 'dotted'
  final bool roundedCorners;

  // Text & Sticky Note Properties
  final String fontFamily;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final TextAlign textAlign;
  final Color stickyBgColor;

  // Navigation & View
  final double zoom;
  final Offset panOffset;
  final bool spotlightEnabled;
  final Offset spotlightCenter;
  final bool showMinimap;
  final bool isFullscreen;
  final bool followTeacherPage;

  // Selection & Clipboard & Undo/Redo
  final Set<String> selectedObjectIds;
  final List<WhiteboardObject> clipboardObjects;
  final List<WhiteboardUndoEntry> undoStack;
  final List<WhiteboardUndoEntry> redoStack;

  // Ephemeral Collaboration State
  final Map<String, WhiteboardRemoteCursor> remoteCursors;
  final Map<String, WhiteboardObject> remotePreviewStrokes;
  final List<WhiteboardLaserPoint> laserPoints;

  const WhiteboardState({
    this.document,
    this.sessionBoards = const [],
    this.templates = const [],
    this.activePageId,
    this.isLoading = false,
    this.wsConnected = false,
    this.saveState = WhiteboardSaveState.saved,
    this.statusMessage,
    this.activeTool = WhiteboardTool.pen,
    this.eraserMode = EraserMode.stroke,
    this.eraserSize = 20.0,
    this.strokeColor = const Color(0xFF0F172A),
    this.fillColor,
    this.strokeWidth = 3.0,
    this.opacity = 1.0,
    this.strokeStyle = 'solid',
    this.roundedCorners = true,
    this.fontFamily = 'sans-serif',
    this.fontSize = 18.0,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.textAlign = TextAlign.left,
    this.stickyBgColor = const Color(0xFFFEF3C7),
    this.zoom = 1.0,
    this.panOffset = Offset.zero,
    this.spotlightEnabled = false,
    this.spotlightCenter = const Offset(480, 300),
    this.showMinimap = false,
    this.isFullscreen = false,
    this.followTeacherPage = true,
    this.selectedObjectIds = const {},
    this.clipboardObjects = const [],
    this.undoStack = const [],
    this.redoStack = const [],
    this.remoteCursors = const {},
    this.remotePreviewStrokes = const {},
    this.laserPoints = const [],
  });

  WhiteboardPage? get activePage {
    final pages = document?.pages ?? [];
    if (pages.isEmpty) return null;
    if (activePageId != null) {
      for (final p in pages) {
        if (p.id == activePageId) return p;
      }
    }
    return pages.first;
  }

  bool get canCurrentUserEdit {
    final doc = document;
    final page = activePage;
    if (doc == null) return false;

    // Staff/Teacher/Host/Admin with OWNER or page management permissions can always edit
    if (doc.myPermission.permission == 'OWNER' ||
        doc.myPermission.canManagePages ||
        doc.myPermission.canManagePermissions) {
      return true;
    }

    // Explicit edit permission
    if (doc.myPermission.canEdit ||
        doc.myPermission.permission == 'EDIT' ||
        doc.myPermission.permission == 'ANNOTATE') {
      if (page != null && page.isLocked) return false;
      return true;
    }

    // Real-time student collaboration enabled and presentation mode is off
    if (doc.collaborationEnabled && !doc.presentationMode) {
      if (page != null && page.isLocked) return false;
      return true;
    }

    return false;
  }

  WhiteboardState copyWith({
    WhiteboardDocument? document,
    List<Map<String, dynamic>>? sessionBoards,
    List<WhiteboardTemplateItem>? templates,
    String? activePageId,
    bool? isLoading,
    bool? wsConnected,
    WhiteboardSaveState? saveState,
    String? statusMessage,
    WhiteboardTool? activeTool,
    EraserMode? eraserMode,
    double? eraserSize,
    Color? strokeColor,
    Color? fillColor,
    bool clearFillColor = false,
    double? strokeWidth,
    double? opacity,
    String? strokeStyle,
    bool? roundedCorners,
    String? fontFamily,
    double? fontSize,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    TextAlign? textAlign,
    Color? stickyBgColor,
    double? zoom,
    Offset? panOffset,
    bool? spotlightEnabled,
    Offset? spotlightCenter,
    bool? showMinimap,
    bool? isFullscreen,
    bool? followTeacherPage,
    Set<String>? selectedObjectIds,
    List<WhiteboardObject>? clipboardObjects,
    List<WhiteboardUndoEntry>? undoStack,
    List<WhiteboardUndoEntry>? redoStack,
    Map<String, WhiteboardRemoteCursor>? remoteCursors,
    Map<String, WhiteboardObject>? remotePreviewStrokes,
    List<WhiteboardLaserPoint>? laserPoints,
  }) {
    return WhiteboardState(
      document: document ?? this.document,
      sessionBoards: sessionBoards ?? this.sessionBoards,
      templates: templates ?? this.templates,
      activePageId: activePageId ?? this.activePageId,
      isLoading: isLoading ?? this.isLoading,
      wsConnected: wsConnected ?? this.wsConnected,
      saveState: saveState ?? this.saveState,
      statusMessage: statusMessage,
      activeTool: activeTool ?? this.activeTool,
      eraserMode: eraserMode ?? this.eraserMode,
      eraserSize: eraserSize ?? this.eraserSize,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: clearFillColor ? null : (fillColor ?? this.fillColor),
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      strokeStyle: strokeStyle ?? this.strokeStyle,
      roundedCorners: roundedCorners ?? this.roundedCorners,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      textAlign: textAlign ?? this.textAlign,
      stickyBgColor: stickyBgColor ?? this.stickyBgColor,
      zoom: zoom ?? this.zoom,
      panOffset: panOffset ?? this.panOffset,
      spotlightEnabled: spotlightEnabled ?? this.spotlightEnabled,
      spotlightCenter: spotlightCenter ?? this.spotlightCenter,
      showMinimap: showMinimap ?? this.showMinimap,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      followTeacherPage: followTeacherPage ?? this.followTeacherPage,
      selectedObjectIds: selectedObjectIds ?? this.selectedObjectIds,
      clipboardObjects: clipboardObjects ?? this.clipboardObjects,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      remoteCursors: remoteCursors ?? this.remoteCursors,
      remotePreviewStrokes: remotePreviewStrokes ?? this.remotePreviewStrokes,
      laserPoints: laserPoints ?? this.laserPoints,
    );
  }
}

class WhiteboardNotifier extends StateNotifier<WhiteboardState> {
  final WhiteboardApiService _api = WhiteboardApiService();
  final WhiteboardWsService _ws = WhiteboardWsService();

  Timer? _autosaveTimer;
  Timer? _laserCleanupTimer;
  final Set<String> _appliedOpIds = {};
  final List<Map<String, dynamic>> _pendingOfflineOps = [];

  WhiteboardNotifier() : super(const WhiteboardState()) {
    _ws.onEvent = _handleWsEvent;
    _ws.onConnectionChanged = _handleWsConnection;
    _laserCleanupTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (state.laserPoints.isEmpty) return;
      final cutoff = DateTime.now().subtract(const Duration(milliseconds: 1600));
      final kept = state.laserPoints.where((pt) => pt.createdAt.isAfter(cutoff)).toList();
      if (kept.length != state.laserPoints.length) {
        state = state.copyWith(laserPoints: kept);
      }
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _laserCleanupTimer?.cancel();
    _ws.dispose();
    super.dispose();
  }

  void _handleWsConnection(bool connected) {
    state = state.copyWith(
      wsConnected: connected,
      saveState: connected
          ? (state.saveState == WhiteboardSaveState.offline ? WhiteboardSaveState.syncing : state.saveState)
          : WhiteboardSaveState.offline,
    );
    if (connected) {
      _reconcileMissedOperations();
    }
  }

  Future<void> _reconcileMissedOperations() async {
    final doc = state.document;
    if (doc == null) return;
    // Replay any offline queued ops
    if (_pendingOfflineOps.isNotEmpty) {
      state = state.copyWith(saveState: WhiteboardSaveState.syncing);
      final queue = List<Map<String, dynamic>>.from(_pendingOfflineOps);
      _pendingOfflineOps.clear();
      for (final op in queue) {
        await _api.applyOperation(
          whiteboardId: doc.id,
          pageId: op['page_id'],
          operationId: op['operation_id'],
          operationType: op['operation_type'],
          objectId: op['object_id'],
          objectType: op['object_type'],
          operationData: op['operation_data'],
        );
      }
      await _persistPendingQueue(doc.id);
    }

    final sync = await _api.syncSince(doc.id, doc.currentRevision);
    if (sync != null) {
      final ops = sync['operations'] as List? ?? [];
      if (ops.isNotEmpty) {
        final refreshed = await _api.fetchWhiteboard(doc.id);
        if (refreshed != null) {
          state = state.copyWith(document: refreshed, saveState: WhiteboardSaveState.saved);
          return;
        }
      }
    }
    if (state.saveState == WhiteboardSaveState.syncing) {
      state = state.copyWith(saveState: WhiteboardSaveState.saved);
    }
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final doc = state.document;
    if (doc == null) return;

    final evType = (event['event_type'] ?? '').toString();
    final opId = event['operation_id']?.toString();
    final payload = event['payload'] is Map<String, dynamic>
        ? event['payload'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (evType == 'pong') return;

    if (evType == 'whiteboard.opened') {
      final collabList = (payload['collaborators'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WhiteboardCollaborator.fromJson)
          .toList();
      final perm = payload['permission'] is Map<String, dynamic>
          ? WhiteboardPermissionInfo.fromJson(payload['permission'])
          : doc.myPermission;
      state = state.copyWith(
        document: doc.copyWith(activeCollaborators: collabList, myPermission: perm),
      );
      return;
    }

    if (evType == 'collaborator.joined' || evType == 'collaborator.left') {
      final collabList = (payload['collaborators'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WhiteboardCollaborator.fromJson)
          .toList();
      state = state.copyWith(document: doc.copyWith(activeCollaborators: collabList));
      return;
    }

    if (evType == 'cursor.moved') {
      final uid = (payload['user_id'] ?? event['user_id'] ?? '').toString();
      if (uid.isEmpty) return;
      final cursors = Map<String, WhiteboardRemoteCursor>.from(state.remoteCursors);
      cursors[uid] = WhiteboardRemoteCursor(
        userId: uid,
        name: (payload['name'] ?? 'User').toString(),
        color: WhiteboardColorHelper.parse(payload['color']?.toString(), fallback: const Color(0xFF2563EB)),
        x: (payload['x'] as num?)?.toDouble() ?? 0,
        y: (payload['y'] as num?)?.toDouble() ?? 0,
        tool: (payload['tool'] ?? 'pen').toString(),
        pageId: event['page_id']?.toString(),
        updatedAt: DateTime.now(),
      );
      state = state.copyWith(remoteCursors: cursors);
      return;
    }

    if (evType == 'laser.moved') {
      final lx = (payload['x'] as num?)?.toDouble() ?? 0;
      final ly = (payload['y'] as num?)?.toDouble() ?? 0;
      final pts = List<WhiteboardLaserPoint>.from(state.laserPoints)
        ..add(WhiteboardLaserPoint(
          position: Offset(lx, ly),
          color: const Color(0xFFEF4444),
          createdAt: DateTime.now(),
        ));
      state = state.copyWith(laserPoints: pts);
      return;
    }

    if (evType == 'stroke.started' || evType == 'stroke.updated') {
      final tempId = (payload['id'] ?? '').toString();
      final pageId = (event['page_id'] ?? state.activePageId ?? '').toString();
      if (tempId.isNotEmpty) {
        final previews = Map<String, WhiteboardObject>.from(state.remotePreviewStrokes);
        previews[tempId] = WhiteboardObject(
          id: tempId,
          pageId: pageId,
          type: (payload['type'] ?? 'stroke').toString(),
          data: payload,
        );
        state = state.copyWith(remotePreviewStrokes: previews);
      }
      return;
    }

    if (evType == 'whiteboard.saved') {
      final rev = (event['revision'] as num?)?.toInt();
      state = state.copyWith(
        saveState: WhiteboardSaveState.saved,
        document: rev != null ? doc.copyWith(currentRevision: rev) : doc,
      );
      return;
    }

    if (evType == 'whiteboard.sync_failed') {
      state = state.copyWith(
        saveState: WhiteboardSaveState.syncFailed,
        statusMessage: payload['reason']?.toString() ?? 'Sync failed',
      );
      return;
    }

    if (evType == 'page.changed') {
      final pid = event['page_id']?.toString();
      if (pid != null && state.followTeacherPage && doc.myPermission.permission != 'OWNER') {
        state = state.copyWith(activePageId: pid);
      }
      return;
    }

    if (evType == 'permission.changed') {
      loadWhiteboard(doc.id);
      return;
    }

    if (evType == 'page.created' || evType == 'page.deleted') {
      loadWhiteboard(doc.id);
      return;
    }

    if (evType == 'page.updated' && payload['operation_type'] != 'page.clear') {
      loadWhiteboard(doc.id);
      return;
    }

    // Deduplicate remote durable operations
    if (opId != null && _appliedOpIds.contains(opId)) {
      return;
    }
    if (opId != null) _appliedOpIds.add(opId);

    final rev = (event['revision'] as num?)?.toInt() ?? doc.currentRevision;
    final pageId = (event['page_id'] ?? state.activePageId ?? '').toString();
    final opType = (payload['operation_type'] ?? '').toString();
    final objId = payload['object_id']?.toString();
    final objType = (payload['object_type'] ?? 'stroke').toString();
    final opData = payload['operation_data'] is Map<String, dynamic>
        ? payload['operation_data'] as Map<String, dynamic>
        : <String, dynamic>{};

    // Clear ephemeral preview if matching
    final previews = Map<String, WhiteboardObject>.from(state.remotePreviewStrokes);
    if (objId != null) previews.remove(objId);

    final updatedPages = doc.pages.map((p) {
      if (p.id != pageId) return p;
      final objs = List<WhiteboardObject>.from(p.objects);
      if (opType == 'object.create' || opType == 'object.update') {
        final objData = opData['data'] is Map<String, dynamic> ? opData['data'] as Map<String, dynamic> : opData;
        final newObj = WhiteboardObject(
          id: objId ?? _uuid.v4(),
          pageId: pageId,
          type: objType,
          data: objData,
          zIndex: (opData['z_index'] as num?)?.toInt() ?? objs.length + 1,
          isLocked: opData['is_locked'] == true,
        );
        final idx = objs.indexWhere((o) => o.id == newObj.id);
        if (idx >= 0) {
          objs[idx] = newObj;
        } else {
          objs.add(newObj);
        }
      } else if (opType == 'object.delete' && objId != null) {
        objs.removeWhere((o) => o.id == objId);
      } else if (opType == 'page.clear') {
        objs.clear();
      }
      return p.copyWith(objects: objs);
    }).toList();

    state = state.copyWith(
      document: doc.copyWith(currentRevision: rev, pages: updatedPages),
      remotePreviewStrokes: previews,
    );
  }

  Future<void> initializeForSession(String? sessionId, {String defaultTitle = 'Whiteboard - Class 10 – Mathematics'}) async {
    state = state.copyWith(isLoading: true);
    final templates = await _api.fetchTemplates();
    var boards = await _api.listWhiteboards(sessionId: sessionId);
    if (boards.isEmpty && sessionId != null) {
      boards = await _api.listWhiteboards();
    }

    WhiteboardDocument? doc;
    if (boards.isNotEmpty) {
      final firstId = boards.first['id'].toString();
      doc = await _api.fetchWhiteboard(firstId);
    } else {
      doc = await _api.createWhiteboard(
        sessionId: sessionId,
        title: defaultTitle,
        templateType: 'mathematics',
        collaborationEnabled: true,
      );
      if (doc != null) {
        boards = await _api.listWhiteboards(sessionId: sessionId);
      }
    }

    if (doc != null) {
      await _restorePendingQueue(doc.id);
      final firstPageId = doc.pages.isNotEmpty ? doc.pages.first.id : null;
      state = state.copyWith(
        document: doc,
        sessionBoards: boards,
        templates: templates,
        activePageId: firstPageId,
        isLoading: false,
        saveState: WhiteboardSaveState.saved,
        undoStack: [],
        redoStack: [],
        selectedObjectIds: {},
      );
      await _ws.connect(doc.id);
    } else {
      state = state.copyWith(isLoading: false, templates: templates, saveState: WhiteboardSaveState.offline);
    }
  }

  Future<void> loadWhiteboard(String whiteboardId) async {
    final doc = await _api.fetchWhiteboard(whiteboardId);
    if (doc == null) return;
    final boards = await _api.listWhiteboards(sessionId: doc.sessionId);
    final currentActive = state.activePageId;
    final hasCurrent = currentActive != null && doc.pages.any((p) => p.id == currentActive);
    state = state.copyWith(
      document: doc,
      sessionBoards: boards.isNotEmpty ? boards : state.sessionBoards,
      activePageId: hasCurrent ? currentActive : (doc.pages.isNotEmpty ? doc.pages.first.id : null),
      saveState: WhiteboardSaveState.saved,
    );
    if (!_ws.isConnected) {
      await _ws.connect(doc.id);
    }
  }

  Future<bool> createNewBoard({
    required String title,
    String templateType = 'blank',
    bool collaborationEnabled = true,
  }) async {
    final sessionId = state.document?.sessionId;
    state = state.copyWith(isLoading: true);
    final created = await _api.createWhiteboard(
      sessionId: sessionId,
      title: title,
      templateType: templateType,
      collaborationEnabled: collaborationEnabled,
    );
    if (created != null) {
      final boards = await _api.listWhiteboards(sessionId: sessionId);
      state = state.copyWith(
        document: created,
        sessionBoards: boards,
        activePageId: created.pages.isNotEmpty ? created.pages.first.id : null,
        isLoading: false,
        saveState: WhiteboardSaveState.saved,
        undoStack: [],
        redoStack: [],
        selectedObjectIds: {},
      );
      await _ws.connect(created.id);
      return true;
    }
    state = state.copyWith(isLoading: false);
    return false;
  }

  Future<void> updateBoardMeta({
    String? title,
    bool? collaborationEnabled,
    bool? presentationMode,
    bool? teacherOnlyMode,
    Map<String, dynamic>? defaultPermissions,
  }) async {
    final doc = state.document;
    if (doc == null) return;
    state = state.copyWith(saveState: WhiteboardSaveState.saving);
    final updated = await _api.updateWhiteboardMeta(
      doc.id,
      title: title,
      collaborationEnabled: collaborationEnabled,
      presentationMode: presentationMode,
      teacherOnlyMode: teacherOnlyMode,
      defaultPermissions: defaultPermissions,
    );
    if (updated != null) {
      state = state.copyWith(document: updated, saveState: WhiteboardSaveState.saved);
    } else {
      state = state.copyWith(saveState: WhiteboardSaveState.syncFailed);
    }
  }

  // Page Actions
  void selectPage(String pageId) {
    if (state.activePageId == pageId) return;
    // Persist any dirty draft / snapshot safely when switching pages
    if (state.saveState == WhiteboardSaveState.unsaved) {
      saveManual(versionName: 'Auto Checkpoint on Page Switch', isCheckpoint: false);
    }
    final pageIdx = state.document?.pages.indexWhere((p) => p.id == pageId) ?? 0;
    state = state.copyWith(
      activePageId: pageId,
      selectedObjectIds: {},
    );
    if (state.document?.myPermission.permission == 'OWNER') {
      _ws.sendPageChanged(pageId, pageIdx + 1);
    }
  }

  void goNextPage() {
    final pages = state.document?.pages ?? [];
    final idx = pages.indexWhere((p) => p.id == state.activePageId);
    if (idx >= 0 && idx + 1 < pages.length) {
      selectPage(pages[idx + 1].id);
    }
  }

  void goPreviousPage() {
    final pages = state.document?.pages ?? [];
    final idx = pages.indexWhere((p) => p.id == state.activePageId);
    if (idx > 0) {
      selectPage(pages[idx - 1].id);
    }
  }

  Future<void> addPage({String? title, WhiteboardBackgroundType? background}) async {
    final doc = state.document;
    if (doc == null || !doc.myPermission.canManagePages) return;
    final nextNum = doc.pages.length + 1;
    final page = await _api.createPage(
      doc.id,
      title: title ?? '$nextNum. Board $nextNum',
      backgroundType: (background ?? WhiteboardBackgroundType.plain).apiValue,
    );
    if (page != null) {
      final nextPages = List<WhiteboardPage>.from(doc.pages)..add(page);
      state = state.copyWith(
        document: doc.copyWith(pages: nextPages),
        activePageId: page.id,
        selectedObjectIds: {},
        saveState: WhiteboardSaveState.saved,
      );
    }
  }

  Future<void> duplicateCurrentPage([String? targetPageId]) async {
    final doc = state.document;
    final pid = targetPageId ?? state.activePageId;
    if (doc == null || pid == null || !doc.myPermission.canManagePages) return;
    final dup = await _api.duplicatePage(doc.id, pid);
    if (dup != null) {
      final nextPages = List<WhiteboardPage>.from(doc.pages)..add(dup);
      state = state.copyWith(
        document: doc.copyWith(pages: nextPages),
        activePageId: dup.id,
      );
    }
  }

  Future<void> renamePage(String pageId, String newTitle) async {
    final doc = state.document;
    if (doc == null || !doc.myPermission.canManagePages) return;
    final updated = await _api.updatePage(doc.id, pageId, title: newTitle);
    if (updated != null) {
      final nextPages = doc.pages.map((p) => p.id == pageId ? p.copyWith(title: updated.title) : p).toList();
      state = state.copyWith(document: doc.copyWith(pages: nextPages));
    }
  }

  Future<void> changePageBackground(WhiteboardBackgroundType bgType) async {
    final doc = state.document;
    final pid = state.activePageId;
    if (doc == null || pid == null || !doc.myPermission.canManagePages) return;
    final nextPages = doc.pages.map((p) => p.id == pid ? p.copyWith(backgroundType: bgType) : p).toList();
    state = state.copyWith(document: doc.copyWith(pages: nextPages), saveState: WhiteboardSaveState.saving);
    final updated = await _api.updatePage(doc.id, pid, backgroundType: bgType.apiValue);
    state = state.copyWith(saveState: updated != null ? WhiteboardSaveState.saved : WhiteboardSaveState.syncFailed);
  }

  Future<void> togglePageLock(String pageId) async {
    final doc = state.document;
    if (doc == null || !doc.myPermission.canManagePages) return;
    final page = doc.pages.firstWhere((p) => p.id == pageId, orElse: () => doc.pages.first);
    final nextLock = !page.isLocked;
    final nextPages = doc.pages.map((p) => p.id == pageId ? p.copyWith(isLocked: nextLock) : p).toList();
    state = state.copyWith(document: doc.copyWith(pages: nextPages));
    await _api.updatePage(doc.id, pageId, isLocked: nextLock);
  }

  Future<bool> deletePage(String pageId) async {
    final doc = state.document;
    if (doc == null || doc.pages.length <= 1 || !doc.myPermission.canManagePages) return false;
    final ok = await _api.deletePage(doc.id, pageId);
    if (ok) {
      final remaining = doc.pages.where((p) => p.id != pageId).toList();
      final nextActive = state.activePageId == pageId ? remaining.first.id : state.activePageId;
      state = state.copyWith(
        document: doc.copyWith(pages: remaining),
        activePageId: nextActive,
        selectedObjectIds: {},
      );
    }
    return ok;
  }

  // Tool & Properties Setters
  void setTool(WhiteboardTool tool) {
    state = state.copyWith(
      activeTool: tool,
      selectedObjectIds: tool == WhiteboardTool.select ? state.selectedObjectIds : {},
    );
  }

  void setStrokeColor(Color color) {
    state = state.copyWith(strokeColor: color);
    _updateSelectedStyle({'color': WhiteboardColorHelper.toHex(color)});
  }

  void setFillColor(Color? color) {
    state = state.copyWith(fillColor: color, clearFillColor: color == null);
    if (color != null) {
      _updateSelectedStyle({'bgColor': WhiteboardColorHelper.toHex(color)});
    }
  }

  void setStrokeWidth(double width) {
    state = state.copyWith(strokeWidth: width);
    _updateSelectedStyle({'strokeWidth': width});
  }

  void setOpacity(double opacity) {
    state = state.copyWith(opacity: opacity);
    _updateSelectedStyle({'opacity': opacity});
  }

  void setStrokeStyle(String style) {
    state = state.copyWith(strokeStyle: style);
    _updateSelectedStyle({'strokeStyle': style});
  }

  void setEraserMode(EraserMode mode) => state = state.copyWith(eraserMode: mode);
  void setEraserSize(double size) => state = state.copyWith(eraserSize: size);
  void setRoundedCorners(bool v) => state = state.copyWith(roundedCorners: v);
  void setFontFamily(String f) => state = state.copyWith(fontFamily: f);
  void setFontSize(double s) => state = state.copyWith(fontSize: s);
  void toggleBold() => state = state.copyWith(isBold: !state.isBold);
  void toggleItalic() => state = state.copyWith(isItalic: !state.isItalic);
  void toggleUnderline() => state = state.copyWith(isUnderline: !state.isUnderline);
  void setTextAlign(TextAlign align) => state = state.copyWith(textAlign: align);
  void setStickyBgColor(Color c) => state = state.copyWith(stickyBgColor: c);
  void toggleSpotlight() => state = state.copyWith(spotlightEnabled: !state.spotlightEnabled);
  void updateSpotlightCenter(Offset c) => state = state.copyWith(spotlightCenter: c);
  void toggleMinimap() => state = state.copyWith(showMinimap: !state.showMinimap);
  void toggleFullscreen() => state = state.copyWith(isFullscreen: !state.isFullscreen);
  void setFollowTeacherPage(bool v) => state = state.copyWith(followTeacherPage: v);

  // Zoom & Pan
  void zoomIn() => state = state.copyWith(zoom: (state.zoom + 0.15).clamp(0.25, 4.0));
  void zoomOut() => state = state.copyWith(zoom: (state.zoom - 0.15).clamp(0.25, 4.0));
  void setZoom(double z) => state = state.copyWith(zoom: z.clamp(0.25, 4.0));
  void setPanOffset(Offset offset) => state = state.copyWith(panOffset: offset);
  void resetView() => state = state.copyWith(zoom: 1.0, panOffset: Offset.zero);
  void fitToScreen(Size viewportSize) {
    const logicalW = 1000.0;
    const logicalH = 620.0;
    final zx = (viewportSize.width - 32) / logicalW;
    final zy = (viewportSize.height - 32) / logicalH;
    final z = (zx < zy ? zx : zy).clamp(0.35, 1.5);
    state = state.copyWith(zoom: z, panOffset: Offset.zero);
  }

  // Selection, Clipboard & Layer Order
  void selectObjects(Set<String> ids) => state = state.copyWith(selectedObjectIds: ids);

  void selectAllOnPage() {
    final page = state.activePage;
    if (page == null) return;
    state = state.copyWith(
      activeTool: WhiteboardTool.select,
      selectedObjectIds: page.objects.map((o) => o.id).toSet(),
    );
  }

  void copySelected() {
    final page = state.activePage;
    if (page == null || state.selectedObjectIds.isEmpty) return;
    final copied = page.objects.where((o) => state.selectedObjectIds.contains(o.id)).toList();
    state = state.copyWith(clipboardObjects: copied, statusMessage: '${copied.length} object(s) copied');
  }

  Future<void> cutSelected() async {
    copySelected();
    await deleteSelectedObjects();
  }

  Future<void> pasteClipboard() async {
    if (state.clipboardObjects.isEmpty || !state.canCurrentUserEdit) return;
    final page = state.activePage;
    if (page == null) return;
    final created = <WhiteboardObject>[];
    for (final src in state.clipboardObjects) {
      final moved = src.movedBy(28, 28).copyWith(
            id: 'obj_${_uuid.v4().substring(0, 8)}',
            pageId: page.id,
            zIndex: page.objects.length + created.length + 1,
          );
      created.add(moved);
      await addObject(moved);
    }
    state = state.copyWith(
      activeTool: WhiteboardTool.select,
      selectedObjectIds: created.map((e) => e.id).toSet(),
    );
  }

  Future<void> duplicateSelected() async {
    copySelected();
    await pasteClipboard();
  }

  Future<void> bringForwardSelected() async {
    final page = state.activePage;
    if (page == null || state.selectedObjectIds.isEmpty || !state.canCurrentUserEdit) return;
    final maxZ = page.objects.fold<int>(0, (prev, o) => o.zIndex > prev ? o.zIndex : prev);
    for (final id in state.selectedObjectIds) {
      final obj = page.objects.firstWhere((o) => o.id == id);
      await updateObject(obj.copyWith(zIndex: maxZ + 1));
    }
  }

  Future<void> sendBackwardSelected() async {
    final page = state.activePage;
    if (page == null || state.selectedObjectIds.isEmpty || !state.canCurrentUserEdit) return;
    final minZ = page.objects.fold<int>(0, (prev, o) => o.zIndex < prev ? o.zIndex : prev);
    for (final id in state.selectedObjectIds) {
      final obj = page.objects.firstWhere((o) => o.id == id);
      await updateObject(obj.copyWith(zIndex: minZ - 1));
    }
  }

  Future<void> _updateSelectedStyle(Map<String, dynamic> patch) async {
    if (state.selectedObjectIds.isEmpty || !state.canCurrentUserEdit) return;
    final page = state.activePage;
    if (page == null) return;
    for (final id in state.selectedObjectIds) {
      final idx = page.objects.indexWhere((o) => o.id == id);
      if (idx < 0) continue;
      final obj = page.objects[idx];
      final nextData = Map<String, dynamic>.from(obj.data)..addAll(patch);
      await updateObject(obj.copyWith(data: nextData));
    }
  }

  // Real-time ephemeral pointer/stroke emitters
  void emitCursor(double x, double y) {
    final pid = state.activePageId;
    if (pid == null) return;
    final isLaser = state.activeTool == WhiteboardTool.laser;
    if (isLaser) {
      final pts = List<WhiteboardLaserPoint>.from(state.laserPoints)
        ..add(WhiteboardLaserPoint(position: Offset(x, y), color: const Color(0xFFEF4444), createdAt: DateTime.now()));
      state = state.copyWith(laserPoints: pts);
    }
    _ws.sendCursorMoved(
      pageId: pid,
      x: x,
      y: y,
      tool: state.activeTool.name,
      isLaser: isLaser,
    );
  }

  void emitStrokePreview(String tempId, List<List<double>> points, String eventType) {
    final pid = state.activePageId;
    if (pid == null || !state.canCurrentUserEdit) return;
    _ws.sendStrokePreview(
      pageId: pid,
      eventType: eventType,
      tempId: tempId,
      points: points,
      colorHex: WhiteboardColorHelper.toHex(state.strokeColor),
      strokeWidth: state.strokeWidth,
      isHighlighter: state.activeTool == WhiteboardTool.highlighter,
    );
  }

  // Durable Object Mutations + Undo/Redo + Autosave
  Future<void> addObject(WhiteboardObject obj, {bool recordUndo = true}) async {
    final doc = state.document;
    final page = state.activePage;
    if (doc == null || page == null || !state.canCurrentUserEdit) return;

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
      saveState: WhiteboardSaveState.saving,
    );

    await _dispatchDurableOperation(
      whiteboardId: doc.id,
      pageId: page.id,
      operationType: 'object.create',
      objectId: obj.id,
      objectType: obj.type,
      operationData: {
        'id': obj.id,
        'type': obj.type,
        'z_index': obj.zIndex,
        'is_locked': obj.isLocked,
        'data': obj.data,
      },
    );
  }

  Future<void> updateObject(WhiteboardObject updated, {bool recordUndo = true}) async {
    final doc = state.document;
    final page = state.activePage;
    if (doc == null || page == null || !state.canCurrentUserEdit) return;

    final existingIdx = page.objects.indexWhere((o) => o.id == updated.id);
    if (existingIdx < 0) return;
    final beforeObj = page.objects[existingIdx];

    final nextObjs = List<WhiteboardObject>.from(page.objects);
    nextObjs[existingIdx] = updated;
    final nextPages = doc.pages.map((p) => p.id == page.id ? p.copyWith(objects: nextObjs) : p).toList();

    final undo = recordUndo
        ? (List<WhiteboardUndoEntry>.from(state.undoStack)
          ..add(WhiteboardUndoEntry(
            pageId: page.id,
            actionType: 'update',
            beforeObjects: [beforeObj],
            afterObjects: [updated],
          )))
        : state.undoStack;

    state = state.copyWith(
      document: doc.copyWith(pages: nextPages),
      undoStack: undo,
      redoStack: recordUndo ? [] : state.redoStack,
      saveState: WhiteboardSaveState.saving,
    );

    await _dispatchDurableOperation(
      whiteboardId: doc.id,
      pageId: page.id,
      operationType: 'object.update',
      objectId: updated.id,
      objectType: updated.type,
      operationData: {
        'id': updated.id,
        'type': updated.type,
        'z_index': updated.zIndex,
        'is_locked': updated.isLocked,
        'data': updated.data,
      },
    );
  }

  Future<void> deleteObjectById(String objectId, {bool recordUndo = true}) async {
    final doc = state.document;
    final page = state.activePage;
    if (doc == null || page == null || !state.canCurrentUserEdit) return;

    final targetIdx = page.objects.indexWhere((o) => o.id == objectId);
    if (targetIdx < 0) return;
    final beforeObj = page.objects[targetIdx];
    if (beforeObj.isLocked && doc.myPermission.permission != 'OWNER') return;

    final nextObjs = page.objects.where((o) => o.id != objectId).toList();
    final nextPages = doc.pages.map((p) => p.id == page.id ? p.copyWith(objects: nextObjs) : p).toList();
    final nextSelected = Set<String>.from(state.selectedObjectIds)..remove(objectId);

    final undo = recordUndo
        ? (List<WhiteboardUndoEntry>.from(state.undoStack)
          ..add(WhiteboardUndoEntry(
            pageId: page.id,
            actionType: 'delete',
            beforeObjects: [beforeObj],
            afterObjects: const [],
          )))
        : state.undoStack;

    state = state.copyWith(
      document: doc.copyWith(pages: nextPages),
      selectedObjectIds: nextSelected,
      undoStack: undo,
      redoStack: recordUndo ? [] : state.redoStack,
      saveState: WhiteboardSaveState.saving,
    );

    await _dispatchDurableOperation(
      whiteboardId: doc.id,
      pageId: page.id,
      operationType: 'object.delete',
      objectId: objectId,
      objectType: beforeObj.type,
      operationData: {'id': objectId},
    );
  }

  Future<void> deleteSelectedObjects() async {
    final ids = List<String>.from(state.selectedObjectIds);
    for (final id in ids) {
      await deleteObjectById(id);
    }
  }

  Future<void> eraseAreaRect(Rect area) async {
    final page = state.activePage;
    if (page == null || !state.canCurrentUserEdit) return;
    final toRemove = page.objects.where((o) => !o.isLocked && o.getBounds().overlaps(area)).map((o) => o.id).toList();
    for (final id in toRemove) {
      await deleteObjectById(id);
    }
  }

  Future<void> clearCurrentPage() async {
    final doc = state.document;
    final page = state.activePage;
    if (doc == null || page == null || !state.canCurrentUserEdit) return;
    if (page.objects.isEmpty) return;

    final before = List<WhiteboardObject>.from(page.objects);
    final nextPages = doc.pages.map((p) => p.id == page.id ? p.copyWith(objects: const []) : p).toList();
    final undo = List<WhiteboardUndoEntry>.from(state.undoStack)
      ..add(WhiteboardUndoEntry(
        pageId: page.id,
        actionType: 'clear_page',
        beforeObjects: before,
        afterObjects: const [],
      ));

    state = state.copyWith(
      document: doc.copyWith(pages: nextPages),
      selectedObjectIds: {},
      undoStack: undo,
      redoStack: [],
      saveState: WhiteboardSaveState.saving,
    );

    await _dispatchDurableOperation(
      whiteboardId: doc.id,
      pageId: page.id,
      operationType: 'page.clear',
      objectId: null,
      objectType: 'page',
      operationData: {'page_id': page.id},
    );
  }

  Future<void> undo() async {
    if (state.undoStack.isEmpty || !state.canCurrentUserEdit) return;
    final entry = state.undoStack.last;
    final nextUndo = List<WhiteboardUndoEntry>.from(state.undoStack)..removeLast();
    final nextRedo = List<WhiteboardUndoEntry>.from(state.redoStack)..add(entry);
    state = state.copyWith(undoStack: nextUndo, redoStack: nextRedo);

    if (entry.actionType == 'create') {
      for (final o in entry.afterObjects) {
        await deleteObjectById(o.id, recordUndo: false);
      }
    } else if (entry.actionType == 'delete' || entry.actionType == 'clear_page') {
      for (final o in entry.beforeObjects) {
        await addObject(o, recordUndo: false);
      }
    } else if (entry.actionType == 'update') {
      for (final o in entry.beforeObjects) {
        await updateObject(o, recordUndo: false);
      }
    }
  }

  Future<void> redo() async {
    if (state.redoStack.isEmpty || !state.canCurrentUserEdit) return;
    final entry = state.redoStack.last;
    final nextRedo = List<WhiteboardUndoEntry>.from(state.redoStack)..removeLast();
    final nextUndo = List<WhiteboardUndoEntry>.from(state.undoStack)..add(entry);
    state = state.copyWith(undoStack: nextUndo, redoStack: nextRedo);

    if (entry.actionType == 'create') {
      for (final o in entry.afterObjects) {
        await addObject(o, recordUndo: false);
      }
    } else if (entry.actionType == 'delete') {
      for (final o in entry.beforeObjects) {
        await deleteObjectById(o.id, recordUndo: false);
      }
    } else if (entry.actionType == 'clear_page') {
      await clearCurrentPage();
    } else if (entry.actionType == 'update') {
      for (final o in entry.afterObjects) {
        await updateObject(o, recordUndo: false);
      }
    }
  }

  Future<void> _dispatchDurableOperation({
    required String whiteboardId,
    required String pageId,
    required String operationType,
    String? objectId,
    String? objectType,
    required Map<String, dynamic> operationData,
  }) async {
    final opId = _uuid.v4();
    _appliedOpIds.add(opId);

    if (_ws.isConnected) {
      _ws.sendOperation(
        pageId: pageId,
        operationId: opId,
        operationType: operationType,
        objectId: objectId,
        objectType: objectType,
        payload: operationData,
      );
      _scheduleAutosaveCheckpoint();
      return;
    }

    // Fallback to REST API when WS is unavailable
    final res = await _api.applyOperation(
      whiteboardId: whiteboardId,
      pageId: pageId,
      operationId: opId,
      operationType: operationType,
      objectId: objectId,
      objectType: objectType,
      operationData: operationData,
    );

    if (res != null && res['success'] == true) {
      final rev = (res['revision'] as num?)?.toInt();
      state = state.copyWith(
        saveState: WhiteboardSaveState.saved,
        document: rev != null ? state.document?.copyWith(currentRevision: rev) : state.document,
      );
      _scheduleAutosaveCheckpoint();
    } else {
      // Cache locally for offline recovery
      _pendingOfflineOps.add({
        'page_id': pageId,
        'operation_id': opId,
        'operation_type': operationType,
        'object_id': objectId,
        'object_type': objectType,
        'operation_data': operationData,
      });
      await _persistPendingQueue(whiteboardId);
      state = state.copyWith(saveState: WhiteboardSaveState.offline);
    }
  }

  void _scheduleAutosaveCheckpoint() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 25), () {
      if (state.document != null) {
        _api.createCheckpoint(
          state.document!.id,
          versionName: 'Autosave Snapshot',
          isCheckpoint: false,
        );
      }
    });
  }

  Future<void> _persistPendingQueue(String whiteboardId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wb_pending_$whiteboardId', jsonEncode(_pendingOfflineOps));
    } catch (_) {}
  }

  Future<void> _restorePendingQueue(String whiteboardId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('wb_pending_$whiteboardId');
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().toList();
        _pendingOfflineOps.clear();
        _pendingOfflineOps.addAll(list);
      }
    } catch (_) {}
  }

  Future<bool> saveManual({String versionName = 'Manual Save Checkpoint', bool isCheckpoint = true}) async {
    final doc = state.document;
    if (doc == null) return false;
    state = state.copyWith(saveState: WhiteboardSaveState.saving);
    if (_pendingOfflineOps.isNotEmpty) {
      await _reconcileMissedOperations();
    }
    final ver = await _api.createCheckpoint(doc.id, versionName: versionName, isCheckpoint: isCheckpoint);
    if (ver != null) {
      final nextVersions = List<WhiteboardVersionItem>.from(doc.versions)..insert(0, ver);
      state = state.copyWith(
        document: doc.copyWith(versions: nextVersions),
        saveState: WhiteboardSaveState.saved,
      );
      return true;
    }
    state = state.copyWith(saveState: WhiteboardSaveState.syncFailed);
    return false;
  }

  Future<bool> restoreVersion(String versionId) async {
    final doc = state.document;
    if (doc == null) return false;
    state = state.copyWith(isLoading: true, saveState: WhiteboardSaveState.syncing);
    final restored = await _api.restoreVersion(doc.id, versionId);
    if (restored != null) {
      state = state.copyWith(
        document: restored,
        activePageId: restored.pages.isNotEmpty ? restored.pages.first.id : null,
        isLoading: false,
        saveState: WhiteboardSaveState.saved,
        selectedObjectIds: {},
      );
      return true;
    }
    state = state.copyWith(isLoading: false, saveState: WhiteboardSaveState.syncFailed);
    return false;
  }

  Future<bool> updateParticipantPermission({
    String? targetUserId,
    String? targetRole,
    required String permissionType,
    Map<String, dynamic>? assignedArea,
  }) async {
    final doc = state.document;
    if (doc == null) return false;
    final ok = await _api.setPermission(
      doc.id,
      targetUserId: targetUserId,
      targetRole: targetRole,
      permissionType: permissionType,
      assignedArea: assignedArea,
    );
    if (ok) {
      await loadWhiteboard(doc.id);
    }
    return ok;
  }

  Future<WhiteboardShareItem?> shareBoard({
    required String shareType,
    required String targetLabel,
    String accessLevel = 'VIEW',
    String? expiresAt,
  }) async {
    final doc = state.document;
    if (doc == null) return null;
    return await _api.shareWhiteboard(
      doc.id,
      shareType: shareType,
      targetLabel: targetLabel,
      accessLevel: accessLevel,
      expiresAt: expiresAt,
    );
  }

  Future<Map<String, dynamic>?> uploadAndInsertAsset({
    required String filename,
    required Uint8List bytes,
    bool importPdfPages = false,
  }) async {
    final doc = state.document;
    final page = state.activePage;
    if (doc == null || page == null) return null;
    final asset = await _api.uploadAsset(
      whiteboardId: doc.id,
      pageId: page.id,
      filename: filename,
      bytes: bytes,
    );
    if (asset == null) return null;

    final mime = (asset['mime_type'] ?? '').toString().toLowerCase();
    final contentUrl = (asset['content_url'] ?? '').toString();
    final pageCount = (asset['page_count'] as num?)?.toInt() ?? 1;

    if (mime == 'application/pdf' && importPdfPages) {
      for (int i = 1; i <= pageCount.clamp(1, 10); i++) {
        final createdPage = await _api.createPage(
          doc.id,
          title: '$filename (p.$i)',
          backgroundType: 'plain',
        );
        if (createdPage != null) {
          final pdfObj = WhiteboardObject(
            id: 'pdf_${_uuid.v4().substring(0, 8)}',
            pageId: createdPage.id,
            type: 'pdf_page',
            data: {
              'x': 60,
              'y': 40,
              'width': 680,
              'height': 520,
              'asset_id': asset['id'],
              'content_url': contentUrl,
              'file_name': filename,
              'pdf_page_number': i,
              'page_count': pageCount,
              'is_locked': true,
            },
            zIndex: 0,
          );
          await _api.applyOperation(
            whiteboardId: doc.id,
            pageId: createdPage.id,
            operationId: _uuid.v4(),
            operationType: 'object.create',
            objectId: pdfObj.id,
            objectType: 'pdf_page',
            operationData: {'id': pdfObj.id, 'type': 'pdf_page', 'z_index': 0, 'data': pdfObj.data},
          );
        }
      }
      await loadWhiteboard(doc.id);
    } else if (mime.startsWith('image/')) {
      final w = ((asset['width'] as num?)?.toDouble() ?? 340).clamp(120.0, 560.0);
      final h = ((asset['height'] as num?)?.toDouble() ?? 240).clamp(90.0, 420.0);
      await addObject(WhiteboardObject(
        id: 'img_${_uuid.v4().substring(0, 8)}',
        pageId: page.id,
        type: 'image',
        data: {
          'x': 180,
          'y': 110,
          'width': w,
          'height': h,
          'asset_id': asset['id'],
          'content_url': contentUrl,
          'file_name': filename,
        },
        zIndex: page.objects.length + 1,
      ));
    } else {
      await addObject(WhiteboardObject(
        id: 'doc_${_uuid.v4().substring(0, 8)}',
        pageId: page.id,
        type: 'pdf_page',
        data: {
          'x': 120,
          'y': 60,
          'width': 520,
          'height': 420,
          'asset_id': asset['id'],
          'content_url': contentUrl,
          'file_name': filename,
          'pdf_page_number': 1,
          'page_count': pageCount,
        },
        zIndex: page.objects.length + 1,
      ));
    }
    return asset;
  }

  Future<Map<String, dynamic>?> exportBoard({
    required String format,
    required String scope,
    List<String>? selectedPageIds,
    String orientation = 'landscape',
  }) async {
    final doc = state.document;
    if (doc == null) return null;
    return await _api.exportWhiteboard(
      whiteboardId: doc.id,
      format: format,
      scope: scope,
      pageId: state.activePageId,
      pageIds: selectedPageIds,
      orientation: orientation,
    );
  }
}

final whiteboardProvider = StateNotifierProvider<WhiteboardNotifier, WhiteboardState>((ref) {
  return WhiteboardNotifier();
});
