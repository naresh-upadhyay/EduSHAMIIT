import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/live_class_management_provider.dart';
import '../../services/in_app_live_room_service.dart';
import '../../widgets/live_class_chat_panel.dart';
import '../models/whiteboard_models.dart';
import '../providers/whiteboard_provider.dart';
import 'edge_label_editor_dialog.dart';
import 'equation_editor_dialog.dart';
import 'whiteboard_canvas_engine.dart';
import 'whiteboard_dialogs.dart';

const _uuid = Uuid();

class WhiteboardWorkspace extends ConsumerStatefulWidget {
  final String? sessionId;
  final String? sessionTitle;
  final VoidCallback? onBackToClassroom;
  final VoidCallback? onEndClass;
  final VoidCallback? onLeaveClass;
  final VoidCallback? onOpenPolls;
  final VoidCallback? onOpenQA;
  final bool isFullscreenRoute;

  const WhiteboardWorkspace({
    super.key,
    this.sessionId,
    this.sessionTitle,
    this.onBackToClassroom,
    this.onEndClass,
    this.onLeaveClass,
    this.onOpenPolls,
    this.onOpenQA,
    this.isFullscreenRoute = false,
  });

  @override
  ConsumerState<WhiteboardWorkspace> createState() => _WhiteboardWorkspaceState();
}

class _WhiteboardWorkspaceState extends ConsumerState<WhiteboardWorkspace> {
  bool _boardsSidebarCollapsed = false;
  bool _showRightPanel = true;
  final GlobalKey<LiveClassChatPanelState> _chatPanelKey = GlobalKey<LiveClassChatPanelState>();
  final int _selectedChatTab = 0;
  final FocusNode _keyboardFocus = FocusNode();
  Timer? _elapsedTimer;
  int _elapsedSeconds = 27 * 60 + 18; // 00:27:18 baseline synchronized with live class

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isFullscreenRoute) {
        final currentDoc = ref.read(whiteboardProvider).document;
        if (currentDoc == null || (widget.sessionId != null && currentDoc.sessionId != widget.sessionId)) {
          ref.read(whiteboardProvider.notifier).initializeForSession(
                widget.sessionId,
                defaultTitle: widget.sessionTitle ?? 'Whiteboard - Class 12 - A – Chemistry',
              );
        }
      }
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _keyboardFocus.dispose();
    super.dispose();
  }

  String _formatElapsed(int totalSec) {
    final h = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _handleEditText(WhiteboardObject? existing, Offset logicalPos) async {
    final s = ref.read(whiteboardProvider);
    final page = s.activePage;
    if (page == null) return;
    final isSticky = existing?.type == 'sticky_note' || s.activeTool == WhiteboardTool.stickyNote;

    final initialText = existing?.data['text']?.toString() ?? existing?.data['label']?.toString() ?? '';
    final initialFs = (existing?.data['fontSize'] as num?)?.toDouble() ?? (isSticky ? 14.0 : s.fontSize);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RichTextEditorDialog(
        initialText: initialText,
        isStickyNote: isSticky,
        initialFontSize: initialFs > 0 ? initialFs : 14.0,
        initialBold: existing?.data['bold'] == true || s.isBold,
        initialItalic: existing?.data['italic'] == true || s.isItalic,
        initialUnderline: existing?.data['underline'] == true || s.isUnderline,
        initialColor: existing?.color ?? s.strokeColor,
        initialBgColor: existing?.bgColor,
      ),
    );
    if (result == null) return;

    final notifier = ref.read(whiteboardProvider.notifier);
    if (existing != null) {
      final merged = Map<String, dynamic>.from(existing.data)..addAll(result);
      if (existing.type == 'connector' || existing.type == 'line' || existing.type == 'arrow') {
        merged['label'] = result['text'];
      }
      if (result['color'] != null) {
        merged['textColor'] = result['color'];
      }
      await notifier.updateObject(existing.copyWith(data: merged));
    } else {
      final newObj = WhiteboardObject(
        id: 'txt_${_uuid.v4().substring(0, 8)}',
        pageId: page.id,
        type: isSticky ? 'sticky_note' : 'text',
        zIndex: page.objects.length + 1,
        data: {
          'x': logicalPos.dx,
          'y': logicalPos.dy,
          'width': isSticky ? 210.0 : 280.0,
          'height': isSticky ? 140.0 : 68.0,
          ...result,
        },
      );
      await notifier.addObject(newObj);
      notifier.selectObjects({newObj.id});
      notifier.setTool(WhiteboardTool.select);
    }
  }

  Future<void> _handleEditEquation(WhiteboardObject? existing, Offset logicalPos) async {
    final s = ref.read(whiteboardProvider);
    final page = s.activePage;
    if (page == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EquationEditorDialog(
        initialLatex: existing?.data['latex']?.toString(),
        initialBgHex: existing?.data['bgColor']?.toString(),
        initialTextColor: existing?.data['color']?.toString(),
        initialFontSize: (existing?.data['fontSize'] as num?)?.toDouble(),
      ),
    );
    if (result == null) return;

    final notifier = ref.read(whiteboardProvider.notifier);
    if (existing != null) {
      final merged = Map<String, dynamic>.from(existing.data)..addAll(result);
      await notifier.updateObject(existing.copyWith(data: merged), recordUndo: true);
    } else {
      await notifier.addObject(WhiteboardObject(
        id: 'eq_${_uuid.v4().substring(0, 8)}',
        pageId: page.id,
        type: 'equation',
        zIndex: page.objects.length + 1,
        data: {
          'x': logicalPos.dx,
          'y': logicalPos.dy,
          'width': 340.0,
          'height': 80.0,
          'fontSize': 20.0,
          'color': '#0F172A',
          'borderColor': '#93C5FD',
          ...result,
        },
      ));
    }
  }

  Future<void> _handleEditEdge(WhiteboardObject existing, Offset logicalPos) async {
    final s = ref.read(whiteboardProvider);
    final page = s.activePage;
    if (page == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EdgeLabelEditorDialog(edge: existing),
    );
    if (result == null) return;

    final notifier = ref.read(whiteboardProvider.notifier);
    final nextData = Map<String, dynamic>.from(existing.data);
    if (result['removeLabel'] == true) {
      nextData.remove('label');
      nextData.remove('text');
    } else if (result['label'] != null) {
      nextData['label'] = result['label'];
      nextData['text'] = result['label'];
    }
    if (result['color'] != null) {
      nextData['color'] = result['color'];
    }
    if (result['strokeStyle'] != null) {
      nextData['strokeStyle'] = result['strokeStyle'];
    }

    final updated = existing.copyWith(
      type: (result['type'] as String?) ?? existing.type,
      data: nextData,
    );
    await notifier.updateObject(updated, recordUndo: true);
  }

  void _openAssetDialog() {
    showDialog(context: context, builder: (_) => const WhiteboardAssetDialog());
  }

  void _openFullscreen() {
    if (widget.isFullscreenRoute) {
      Navigator.pop(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhiteboardScreen(
          sessionId: widget.sessionId,
          sessionTitle: widget.sessionTitle,
          onEndClass: widget.onEndClass,
        ),
      ),
    );
  }

  Future<void> _promptEditBoardTitle() async {
    final doc = ref.read(whiteboardProvider).document;
    if (doc == null || !doc.myPermission.canManagePages) return;
    final ctrl = TextEditingController(text: doc.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Whiteboard'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (next != null && next.isNotEmpty) {
      await ref.read(whiteboardProvider.notifier).updateBoardMeta(title: next);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final notifier = ref.read(whiteboardProvider.notifier);

    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (shift) {
        notifier.redo();
      } else {
        notifier.undo();
      }
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      notifier.saveManual();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      notifier.copySelected();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyX) {
      notifier.cutSelected();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyV) {
      notifier.pasteClipboard();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyA) {
      notifier.selectAllOnPage();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      if (ref.read(whiteboardProvider).selectedObjectIds.isNotEmpty) {
        notifier.deleteSelectedObjects();
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.f2) {
      final s = ref.read(whiteboardProvider);
      if (s.selectedObjectIds.length == 1 && s.activePage != null) {
        final selId = s.selectedObjectIds.first;
        final obj = s.activePage!.objects.where((o) => o.id == selId).firstOrNull;
        if (obj != null && (obj.type == 'text' || obj.type == 'sticky_note' || obj.type == 'rectangle' || obj.type == 'diamond' || obj.type == 'circle' || obj.type == 'ellipse' || obj.type == 'connector')) {
          final x = (obj.data['x'] as num?)?.toDouble() ?? 100.0;
          final y = (obj.data['y'] as num?)?.toDouble() ?? 100.0;
          _handleEditText(obj, Offset(x, y));
          return KeyEventResult.handled;
        }
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      notifier.selectObjects({});
      notifier.setTool(WhiteboardTool.select);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.equal || event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      notifier.zoomIn();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus || event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      notifier.zoomOut();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Icon(Icons.draw_outlined, color: Color(0xFF2563EB), size: 18),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open Whiteboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                'Collaborate, teach and explain in real time using an interactive whiteboard.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (widget.onBackToClassroom != null)
          OutlinedButton.icon(
            onPressed: widget.onBackToClassroom,
            icon: const Icon(Icons.arrow_back_rounded, size: 14),
            label: const Text('Back to Classroom', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wbState = ref.watch(whiteboardProvider);
    final lcState = ref.watch(liveClassManagementProvider);
    final roomService = ref.watch(liveRoomServiceProvider);
    final doc = wbState.document;

    final int participantCount = roomService.isConnected
        ? roomService.participantTracks.where((t) => !t.isScreenShare).length
        : (lcState.conductSessionData?.participants.length ??
            lcState.joinDashboard?.participants.length ??
            1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final isCompact = screenW < 1050;
        final hasBoundedHeight = constraints.hasBoundedHeight;

        final mainRow = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT: Whiteboard Workspace Card
            Expanded(
              flex: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildCardTopToolbar(wbState, doc),
                    _buildContextualToolPropertiesBar(wbState),
                    Expanded(
                      child: Row(
                        children: [
                          if (!_boardsSidebarCollapsed && !isCompact)
                            _buildBoardsPageSidebar(wbState, doc),
                          _buildLeftDrawingToolbar(wbState),
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: wbState.isLoading && doc == null
                                      ? const Center(child: CircularProgressIndicator())
                                      : WhiteboardCanvasEngine(
                                          onEditText: _handleEditText,
                                          onEditEquation: _handleEditEquation,
                                          onEditEdge: _handleEditEdge,
                                          onRequestImageUpload: _openAssetDialog,
                                        ),
                                ),
                                // Bottom Canvas Floating Toolbar (Swatches + 3px + Clear)
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 12,
                                  child: _buildBottomFloatingCanvasBar(wbState),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showRightPanel && !isCompact) ...[
              const SizedBox(width: 12),
              // RIGHT: Matching meeting participants, chat, and Q&A (removes duplicate code!)
              SizedBox(
                width: screenW > 1400 ? 330 : 290,
                child: LiveClassChatPanel(
                  key: _chatPanelKey,
                  initialTabIndex: _selectedChatTab,
                  onClose: () => setState(() => _showRightPanel = false),
                ),
              ),
            ],
          ],
        );

        final Widget mainArea = hasBoundedHeight
            ? Expanded(child: mainRow)
            : SizedBox(
                height: isCompact ? 560 : 640,
                child: mainRow,
              );

        return Focus(
          focusNode: _keyboardFocus,
          autofocus: !widget.isFullscreenRoute,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isFullscreenRoute) ...[
                _buildTopHeader(),
                const SizedBox(height: 10),
              ],

              // MAIN COLLABORATIVE WHITEBOARD + PARTICIPANTS ROW
              mainArea,

              const SizedBox(height: 10),

              // BOTTOM PERSISTENT LIVE SESSION CONTROL BAR (Matching mockup footer)
              _buildBottomLiveSessionBar(participantCount, roomService, lcState, wbState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardTopToolbar(WhiteboardState wbState, WhiteboardDocument? doc) {
    final notifier = ref.read(whiteboardProvider.notifier);
    final roomService = ref.watch(liveRoomServiceProvider);
    final saveBadge = _buildSaveStatusBadge(wbState.saveState, wbState.wsConnected);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (widget.isFullscreenRoute && widget.onBackToClassroom != null) ...[
              TextButton.icon(
                onPressed: widget.onBackToClassroom,
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: const Text('Back to Classroom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.co_present_rounded, color: Color(0xFF2563EB), size: 16),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _promptEditBoardTitle,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Text(
                    widget.sessionTitle ?? doc?.title ?? 'Whiteboard - Class 12 - A – Chemistry',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  if (doc?.myPermission.canManagePages == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.edit_outlined, size: 13, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Live indicator pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Live', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            saveBadge,
            const SizedBox(width: 8),

            // Network Quality HUD Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: (roomService.currentPacketLoss > 2.0)
                    ? const Color(0xFFFEE2E2)
                    : (roomService.currentRttMs > 120
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDCFCE7)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (roomService.currentPacketLoss > 2.0)
                      ? const Color(0xFFF87171)
                      : (roomService.currentRttMs > 120
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF86EFAC)),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.network_check_rounded,
                    size: 11,
                    color: (roomService.currentPacketLoss > 2.0)
                        ? const Color(0xFFB91C1C)
                        : (roomService.currentRttMs > 120
                            ? const Color(0xFFB45309)
                            : const Color(0xFF15803D)),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${roomService.currentRttMs} ms',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: (roomService.currentPacketLoss > 2.0)
                          ? const Color(0xFFB91C1C)
                          : (roomService.currentRttMs > 120
                              ? const Color(0xFFB45309)
                              : const Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Undo/Redo & Zoom controls
            _iconBtn(Icons.undo_rounded, 'Undo (Ctrl+Z)', wbState.undoStack.isNotEmpty ? notifier.undo : null),
            _iconBtn(Icons.redo_rounded, 'Redo (Ctrl+Shift+Z)', wbState.redoStack.isNotEmpty ? notifier.redo : null),
            _iconBtn(Icons.zoom_out_rounded, 'Zoom Out', notifier.zoomOut),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: notifier.resetView,
                child: Text('${(wbState.zoom * 100).round()}%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              ),
            ),
            _iconBtn(Icons.zoom_in_rounded, 'Zoom In', notifier.zoomIn),
            _iconBtn(Icons.fit_screen_outlined, 'Reset / Fit View', notifier.resetView),
            const SizedBox(width: 10),

            // + New Board
            ElevatedButton.icon(
              onPressed: doc?.myPermission.canManagePages == false
                  ? null
                  : () => showDialog(context: context, builder: (_) => const WhiteboardTemplatesDialog()),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('New Board', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
            ),
            const SizedBox(width: 6),
            _outlineActionBtn(Icons.save_outlined, 'Save', () async {
              final ok = await notifier.saveManual();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Whiteboard saved cleanly!' : 'Save failed — offline draft preserved.')),
                );
              }
            }),
            const SizedBox(width: 6),
            _outlineActionBtn(Icons.share_outlined, 'Share', () {
              showDialog(context: context, builder: (_) => const WhiteboardShareDialog());
            }),
            const SizedBox(width: 6),
            _outlineActionBtn(Icons.download_outlined, 'Export', () {
              showDialog(context: context, builder: (_) => const WhiteboardExportDialog());
            }),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'More Actions',
              icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF475569)),
              onSelected: (v) {
                if (v == 'history') {
                  showDialog(context: context, builder: (_) => const WhiteboardVersionHistoryDialog());
                } else if (v == 'permissions') {
                  showDialog(context: context, builder: (_) => const WhiteboardPermissionsDialog());
                } else if (v == 'spotlight') {
                  notifier.toggleSpotlight();
                } else if (v == 'boards_collapse') {
                  setState(() => _boardsSidebarCollapsed = !_boardsSidebarCollapsed);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'history', child: Text('Version History & Checkpoints', style: TextStyle(fontSize: 12))),
                PopupMenuItem(value: 'permissions', child: Text('Permissions & Lock Controls', style: TextStyle(fontSize: 12))),
                PopupMenuItem(value: 'spotlight', child: Text('Toggle Teacher Spotlight', style: TextStyle(fontSize: 12))),
                PopupMenuItem(value: 'boards_collapse', child: Text('Toggle Boards Panel', style: TextStyle(fontSize: 12))),
              ],
            ),
            IconButton(
              tooltip: _showRightPanel ? 'Hide Meeting Panel' : 'Show Meeting Panel (Participants/Chat/Q&A)',
              icon: Icon(
                _showRightPanel ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
                size: 17,
                color: _showRightPanel ? const Color(0xFF2563EB) : const Color(0xFF475569),
              ),
              onPressed: () => setState(() => _showRightPanel = !_showRightPanel),
            ),
            IconButton(
              tooltip: widget.isFullscreenRoute ? 'Exit Fullscreen' : 'Fullscreen Whiteboard',
              icon: Icon(widget.isFullscreenRoute ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, size: 17, color: const Color(0xFF475569)),
              onPressed: _openFullscreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveStatusBadge(WhiteboardSaveState state, bool wsConnected) {
    Color bg;
    Color fg;
    String txt;
    IconData icon;

    switch (state) {
      case WhiteboardSaveState.saving:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        txt = 'Saving...';
        icon = Icons.sync_rounded;
        break;
      case WhiteboardSaveState.unsaved:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        txt = 'Unsaved Changes';
        icon = Icons.edit_notifications_outlined;
        break;
      case WhiteboardSaveState.offline:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        txt = 'Offline';
        icon = Icons.cloud_off_rounded;
        break;
      case WhiteboardSaveState.syncing:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        txt = 'Syncing...';
        icon = Icons.cloud_sync_rounded;
        break;
      case WhiteboardSaveState.syncFailed:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        txt = 'Sync Failed';
        icon = Icons.error_outline_rounded;
        break;
      case WhiteboardSaveState.saved:
        bg = const Color(0xFFF8FAFC);
        fg = const Color(0xFF475569);
        txt = wsConnected ? 'Saved • Live Sync' : 'Saved';
        icon = Icons.cloud_done_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(txt, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _buildContextualToolPropertiesBar(WhiteboardState s) {
    final notifier = ref.read(whiteboardProvider.notifier);
    final activeBg = s.activePage?.backgroundType ?? WhiteboardBackgroundType.plain;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('Tool: ${s.activeTool.name.toUpperCase()}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            const SizedBox(width: 12),
            // Background quick switcher
            const Text('Canvas:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(width: 4),
            DropdownButtonHideUnderline(
              child: DropdownButton<WhiteboardBackgroundType>(
                value: activeBg,
                isDense: true,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                items: WhiteboardBackgroundType.values
                    .map((bg) => DropdownMenuItem(value: bg, child: Text(bg.label)))
                    .toList(),
                onChanged: (bg) {
                  if (bg != null) notifier.changePageBackground(bg);
                },
              ),
            ),
            const SizedBox(width: 14),
            if (s.activeTool == WhiteboardTool.eraser) ...[
              const Text('Eraser Mode:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(width: 6),
              for (final m in EraserMode.values)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text(m.name, style: const TextStyle(fontSize: 10)),
                    selected: s.eraserMode == m,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => notifier.setEraserMode(m),
                  ),
                ),
            ] else if (s.activeTool == WhiteboardTool.select && s.selectedObjectIds.isNotEmpty) ...[
              Text('${s.selectedObjectIds.length} selected', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              const SizedBox(width: 8),
              if (s.selectedObjectIds.length == 1) ...[
                () {
                  final sel = s.activePage?.objects.where((o) => o.id == s.selectedObjectIds.first).firstOrNull;
                  if (sel == null) return const SizedBox.shrink();
                  if (sel.isLineBased) {
                    final edgeLabel = sel.data['label']?.toString() ?? sel.data['text']?.toString() ?? 'connects to';
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.edit_note_rounded, size: 14),
                        label: Text('Edit Edge: "$edgeLabel"', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          foregroundColor: const Color(0xFF1D4ED8),
                        ),
                        onPressed: () => _handleEditEdge(sel, Offset.zero),
                      ),
                    );
                  } else if (sel.type == 'equation') {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.functions_rounded, size: 14),
                        label: const Text('Edit Equation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          foregroundColor: const Color(0xFF6D28D9),
                        ),
                        onPressed: () => _handleEditEquation(sel, Offset.zero),
                      ),
                    );
                  } else if (sel.type == 'text' || sel.type == 'sticky') {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.text_fields_rounded, size: 14),
                        label: const Text('Edit Text', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          foregroundColor: const Color(0xFF0369A1),
                        ),
                        onPressed: () => _handleEditText(sel, Offset.zero),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }(),
              ],
              TextButton.icon(icon: const Icon(Icons.copy_rounded, size: 13), label: const Text('Duplicate', style: TextStyle(fontSize: 11)), onPressed: notifier.duplicateSelected),
              TextButton.icon(icon: const Icon(Icons.flip_to_front, size: 13), label: const Text('Forward', style: TextStyle(fontSize: 11)), onPressed: notifier.bringForwardSelected),
              TextButton.icon(icon: const Icon(Icons.flip_to_back, size: 13), label: const Text('Back', style: TextStyle(fontSize: 11)), onPressed: notifier.sendBackwardSelected),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 13, color: Colors.red),
                label: const Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red)),
                onPressed: notifier.deleteSelectedObjects,
              ),
            ] else ...[
              const Text('Opacity:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              SizedBox(
                width: 90,
                child: Slider(
                  value: s.opacity,
                  min: 0.2,
                  max: 1.0,
                  onChanged: notifier.setOpacity,
                ),
              ),
              Text('${(s.opacity * 100).round()}%', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              if (s.activeTool == WhiteboardTool.rectangle ||
                  s.activeTool == WhiteboardTool.circle ||
                  s.activeTool == WhiteboardTool.ellipse ||
                  s.activeTool == WhiteboardTool.triangle ||
                  s.activeTool == WhiteboardTool.star ||
                  s.activeTool == WhiteboardTool.polygon) ...[
                const Text('Fill:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => notifier.setFillColor(null),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: s.fillColor == null ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1), width: 1.8),
                    ),
                    child: const Icon(Icons.close, size: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 4),
                for (final fc in [const Color(0xFFDBEAFE), const Color(0xFFFEF08A), const Color(0xFFDCFCE7), const Color(0xFFFCE7F3)])
                  GestureDetector(
                    onTap: () => notifier.setFillColor(fc),
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: fc,
                        shape: BoxShape.circle,
                        border: Border.all(color: s.fillColor == fc ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1), width: 1.6),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoardsPageSidebar(WhiteboardState s, WhiteboardDocument? doc) {
    final pages = doc?.pages ?? [];
    final notifier = ref.read(whiteboardProvider.notifier);

    return Container(
      width: 146,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Boards (${pages.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _boardsSidebarCollapsed = true),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: pages.length,
              itemBuilder: (ctx, idx) {
                final p = pages[idx];
                final active = p.id == s.activePageId;
                return GestureDetector(
                  onTap: () => notifier.selectPage(p.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                          child: SizedBox(
                            height: 68,
                            child: CustomPaint(painter: WhiteboardThumbnailPainter(page: p)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.title,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                    color: active ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (p.isLocked)
                                const Icon(Icons.lock_outline, size: 11, color: Color(0xFFF59E0B)),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_vert, size: 13, color: Color(0xFF94A3B8)),
                                onSelected: (act) async {
                                  if (act == 'dup') {
                                    notifier.duplicateCurrentPage(p.id);
                                  } else if (act == 'lock') {
                                    notifier.togglePageLock(p.id);
                                  } else if (act == 'del') {
                                    notifier.deletePage(p.id);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'dup', child: Text('Duplicate Page', style: TextStyle(fontSize: 11))),
                                  PopupMenuItem(value: 'lock', child: Text('Toggle Lock', style: TextStyle(fontSize: 11))),
                                  PopupMenuItem(value: 'del', child: Text('Delete Page', style: TextStyle(fontSize: 11, color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: doc?.myPermission.canManagePages == false ? null : () => notifier.addPage(),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Add Board', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                minimumSize: const Size(double.infinity, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftDrawingToolbar(WhiteboardState s) {
    final notifier = ref.read(whiteboardProvider.notifier);

    final tools = <Map<String, dynamic>>[
      {'tool': WhiteboardTool.select, 'icon': Icons.near_me_outlined, 'tip': 'Select & Move (Esc)'},
      {'tool': WhiteboardTool.pan, 'icon': Icons.pan_tool_alt_outlined, 'tip': 'Hand / Pan Canvas'},
      {'tool': WhiteboardTool.pen, 'icon': Icons.edit_outlined, 'tip': 'Pen'},
      {'tool': WhiteboardTool.pencil, 'icon': Icons.create_outlined, 'tip': 'Pencil'},
      {'tool': WhiteboardTool.highlighter, 'icon': Icons.highlight_outlined, 'tip': 'Highlighter'},
      {'tool': WhiteboardTool.eraser, 'icon': Icons.auto_fix_normal_outlined, 'tip': 'Eraser'},
      {'tool': WhiteboardTool.line, 'icon': Icons.horizontal_rule_rounded, 'tip': 'Line'},
      {'tool': WhiteboardTool.arrow, 'icon': Icons.arrow_right_alt_rounded, 'tip': 'Arrow'},
      {'tool': WhiteboardTool.rectangle, 'icon': Icons.crop_square_rounded, 'tip': 'Rectangle'},
      {'tool': WhiteboardTool.circle, 'icon': Icons.circle_outlined, 'tip': 'Circle'},
      {'tool': WhiteboardTool.triangle, 'icon': Icons.change_history_rounded, 'tip': 'Triangle'},
      {'tool': WhiteboardTool.star, 'icon': Icons.star_border_rounded, 'tip': 'Star'},
      {'tool': WhiteboardTool.text, 'icon': Icons.title_rounded, 'tip': 'Rich Text'},
      {'tool': WhiteboardTool.stickyNote, 'icon': Icons.sticky_note_2_outlined, 'tip': 'Sticky Note'},
      {'tool': WhiteboardTool.image, 'icon': Icons.image_outlined, 'tip': 'Insert Image / PDF'},
      {'tool': WhiteboardTool.equation, 'icon': Icons.functions_rounded, 'tip': 'Math Equation Editor'},
      {'tool': WhiteboardTool.laser, 'icon': Icons.flare_rounded, 'tip': 'Laser Pointer'},
      {'tool': WhiteboardTool.measurement, 'icon': Icons.straighten_rounded, 'tip': 'Measurement / Dimension'},
      {'tool': WhiteboardTool.studentZone, 'icon': Icons.group_work_outlined, 'tip': 'Student Work Area'},
    ];

    return Container(
      width: 46,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final item in tools) ...[
              Tooltip(
                message: item['tip'] as String,
                child: InkWell(
                  onTap: () {
                    final tool = item['tool'] as WhiteboardTool;
                    notifier.setTool(tool);
                    if (tool == WhiteboardTool.image) {
                      _openAssetDialog();
                    } else if (tool == WhiteboardTool.equation) {
                      _handleEditEquation(null, const Offset(220, 180));
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 34,
                    height: 32,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: s.activeTool == item['tool'] ? const Color(0xFF2563EB) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 17,
                      color: s.activeTool == item['tool'] ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
            const Divider(height: 12),
            Tooltip(
              message: 'Undo',
              child: InkWell(
                onTap: s.undoStack.isNotEmpty ? notifier.undo : null,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.undo_rounded, size: 17, color: s.undoStack.isNotEmpty ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ),
            Tooltip(
              message: 'Redo',
              child: InkWell(
                onTap: s.redoStack.isNotEmpty ? notifier.redo : null,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.redo_rounded, size: 17, color: s.redoStack.isNotEmpty ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomFloatingCanvasBar(WhiteboardState s) {
    final notifier = ref.read(whiteboardProvider.notifier);
    final colors = [
      const Color(0xFF0F172A),
      const Color(0xFFDC2626),
      const Color(0xFF2563EB),
      const Color(0xFF16A34A),
      const Color(0xFF06B6D4),
      const Color(0xFF7C3AED),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in colors)
                    GestureDetector(
                      onTap: () => notifier.setStrokeColor(c),
                      child: Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.strokeColor == c ? const Color(0xFF2563EB) : Colors.transparent,
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 18, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<double>(
                      value: [2.0, 3.0, 5.0, 8.0].contains(s.strokeWidth) ? s.strokeWidth : 3.0,
                      isDense: true,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      items: [2.0, 3.0, 5.0, 8.0]
                          .map((w) => DropdownMenuItem(value: w, child: Text('${w.toInt()}px')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) notifier.setStrokeWidth(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 18, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 8),
                  for (final w in [2.0, 4.0, 7.0])
                    InkWell(
                      onTap: () => notifier.setStrokeWidth(w),
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        alignment: Alignment.center,
                        child: Container(
                          width: 16,
                          height: w * 0.65,
                          decoration: BoxDecoration(
                            color: s.strokeWidth == w ? const Color(0xFF2563EB) : const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Bottom right quick pen & clear canvas card matching mockup
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => notifier.setTool(WhiteboardTool.pen),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF334155)),
                    ),
                  ),
                  Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                  InkWell(
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear Current Board Page?'),
                          content: const Text('This clears all drawings on the current page. You can still Undo or restore from Version History.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear Page'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await notifier.clearCurrentPage();
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomLiveSessionBar(
    int totalParticipants,
    InAppLiveRoomService roomService,
    LiveClassState lcState,
    WhiteboardState wbState,
  ) {
    final activeSess = lcState.conductSessionData?.activeSession ?? lcState.joinDashboard?.activeSession;
    final selectedClass = lcState.selectedMyClass;
    final sessionTitle = (activeSess != null && activeSess.classSection.isNotEmpty)
        ? '${activeSess.classSection} : ${activeSess.subject} – ${activeSess.title}'
        : (selectedClass != null
            ? '${selectedClass.classSection} : ${selectedClass.subjectName} – ${selectedClass.topic}'
            : (widget.sessionTitle ?? 'Class 12 - A – Chemistry'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final isNarrow = constraints.maxWidth < 850;
        final isMedium = constraints.maxWidth < 1100;
        final showTitle = constraints.maxWidth >= 680;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              // Left: Live badge + Session timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatElapsed(_elapsedSeconds), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              if (showTitle) ...[
                const SizedBox(width: 8),
                const Text('|', style: TextStyle(color: Color(0xFFCBD5E1))),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth < 1100 ? 200 : 360),
                  child: Text(
                    sessionTitle,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(width: 8),

              // Center: Scrollable Controls Bar (Adaptive & Never clips)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _footerCtrlBtn(
                          roomService.isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          roomService.isMicMuted ? 'Unmute' : 'Mute',
                          isIconOnly: isMedium,
                          iconColor: roomService.isMicMuted ? const Color(0xFFDC2626) : const Color(0xFF334155),
                          onTap: roomService.toggleMic,
                        ),
                        _footerCtrlBtn(
                          roomService.isCamOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          roomService.isCamOff ? 'Start Video' : 'Stop Video',
                          isIconOnly: isMedium,
                          onTap: roomService.toggleCamera,
                        ),
                        _footerCtrlBtn(
                          Icons.groups_rounded,
                          'Participants ($totalParticipants)',
                          isIconOnly: isMedium,
                          onTap: () {
                            if (!_showRightPanel) setState(() => _showRightPanel = true);
                            _chatPanelKey.currentState?.selectTab(0);
                          },
                        ),
                        _footerCtrlBtn(
                          Icons.chat_bubble_outline_rounded,
                          'Chat',
                          isIconOnly: isMedium,
                          onTap: () {
                            if (!_showRightPanel) setState(() => _showRightPanel = true);
                            _chatPanelKey.currentState?.selectTab(1);
                          },
                        ),
                        _footerCtrlBtn(
                          Icons.draw_rounded,
                          'Whiteboard',
                          isActive: true,
                          isIconOnly: isMedium,
                          onTap: widget.onBackToClassroom ?? () {},
                        ),
                        _footerCtrlBtn(
                          Icons.screen_share_outlined,
                          'Share Screen',
                          isIconOnly: isMedium,
                          onTap: roomService.toggleScreenShare,
                        ),
                        if (!isNarrow) ...[
                          _footerCtrlBtn(
                            Icons.poll_outlined,
                            'Polls',
                            isIconOnly: isMedium,
                            onTap: () {
                              if (!_showRightPanel) setState(() => _showRightPanel = true);
                              _chatPanelKey.currentState?.selectTab(2);
                              widget.onOpenPolls?.call();
                            },
                          ),
                          _footerCtrlBtn(
                            Icons.live_help_outlined,
                            'Q&A',
                            isIconOnly: isMedium,
                            onTap: () {
                              if (!_showRightPanel) setState(() => _showRightPanel = true);
                              _chatPanelKey.currentState?.selectTab(2);
                            },
                          ),
                        ] else ...[
                          PopupMenuButton<String>(
                            tooltip: 'More Classroom Tools',
                            icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF475569)),
                            onSelected: (v) {
                              if (v == 'polls') {
                                if (!_showRightPanel) setState(() => _showRightPanel = true);
                                _chatPanelKey.currentState?.selectTab(2);
                                widget.onOpenPolls?.call();
                              } else if (v == 'qa') {
                                if (!_showRightPanel) setState(() => _showRightPanel = true);
                                _chatPanelKey.currentState?.selectTab(2);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'polls', child: Text('Live Polls', style: TextStyle(fontSize: 12))),
                              PopupMenuItem(value: 'qa', child: Text('Q&A Panel', style: TextStyle(fontSize: 12))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Right: PINNED End / Leave Class Button (Always fully visible, role-enforced)
              Builder(
                builder: (context) {
                  final role = ref.watch(liveRoomServiceProvider).currentUserRole.toLowerCase();
                  final isStudent = role != 'teacher' && role != 'host' && role != 'co-host' && role != 'super_admin' && role != 'admin';

                  if (isStudent) {
                    return ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E222D),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.logout_rounded, color: Color(0xFFF59E0B), size: 22),
                                SizedBox(width: 8),
                                Text('Leave Live Class?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            content: const Text(
                              'Are you sure you want to leave this session? The teacher and class will continue. You can rejoin anytime from your schedule while the class is live.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Stay in Class', style: TextStyle(color: Colors.white60)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Leave Class', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(whiteboardProvider.notifier).saveManual(versionName: 'Student Leave Notes');
                          final roomService = ref.read(liveRoomServiceProvider);
                          await roomService.leaveRoom();
                          if (widget.onLeaveClass != null) {
                            widget.onLeaveClass!.call();
                          } else {
                            widget.onEndClass?.call();
                          }
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 14),
                      label: Text(
                        isCompact ? 'Leave' : 'Leave Class',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 8),
                        minimumSize: Size(isCompact ? 54 : 80, 34),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    );
                  }

                  return ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E222D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.call_end_rounded, color: Colors.redAccent, size: 24),
                              SizedBox(width: 8),
                              Text('End Live Class for All?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          content: const Text(
                            'Ending this live class will save the current whiteboard session for all participants and trigger attendance calculations.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('End Class for All'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(whiteboardProvider.notifier).saveManual(versionName: 'End Class Final Save');
                        widget.onEndClass?.call();
                      }
                    },
                    icon: const Icon(Icons.call_end_rounded, size: 14),
                    label: Text(
                      isCompact ? 'End' : 'End Class',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 8),
                      minimumSize: Size(isCompact ? 54 : 80, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _footerCtrlBtn(IconData icon, String label, {bool isActive = false, bool isIconOnly = false, Color? iconColor, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isIconOnly ? 8 : 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: isActive ? Colors.white : (iconColor ?? const Color(0xFF334155))),
                if (!isIconOnly) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 17, color: onTap != null ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  Widget _outlineActionBtn(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    );
  }
}

/// Fullscreen dedicated route wrapper preserving session & board state with "Back to Classroom".
class WhiteboardScreen extends ConsumerWidget {
  final String? sessionId;
  final String? sessionTitle;
  final VoidCallback? onEndClass;
  final VoidCallback? onLeaveClass;

  const WhiteboardScreen({
    super.key,
    this.sessionId,
    this.sessionTitle,
    this.onEndClass,
    this.onLeaveClass,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: WhiteboardWorkspace(
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            isFullscreenRoute: true,
            onBackToClassroom: () => Navigator.of(context).pop(),
            onLeaveClass: () {
              onLeaveClass?.call();
              Navigator.of(context).pop();
            },
            onEndClass: () {
              onEndClass?.call();
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
}
