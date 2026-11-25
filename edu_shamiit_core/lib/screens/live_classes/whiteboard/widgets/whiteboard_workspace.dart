import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
  final bool isEmbeddedInStage;
  final bool isOfflineTab;
  final bool isTabActive;

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
    this.isEmbeddedInStage = false,
    this.isOfflineTab = false,
    this.isTabActive = true,
  });

  @override
  ConsumerState<WhiteboardWorkspace> createState() => _WhiteboardWorkspaceState();
}

class _WhiteboardWorkspaceState extends ConsumerState<WhiteboardWorkspace> {
  bool _boardsSidebarCollapsed = false;
  bool _historyDrawerOpen = false;
  String _historySearchQuery = '';
  String _historyFilter = 'All';
  final TextEditingController _historySearchCtrl = TextEditingController();
  bool _showRightPanel = true;
  final GlobalKey<LiveClassChatPanelState> _chatPanelKey = GlobalKey<LiveClassChatPanelState>();
  final int _selectedChatTab = 0;
  final FocusNode _keyboardFocus = FocusNode();
  Timer? _elapsedTimer;
  int _elapsedSeconds = 27 * 60 + 18; // 00:27:18 baseline synchronized with live class

  @override
  void initState() {
    super.initState();
    if (widget.isEmbeddedInStage || widget.isOfflineTab) {
      _showRightPanel = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureInitializedForMode();
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _ensureInitializedForMode() {
    if (widget.isFullscreenRoute || !widget.isTabActive) return;
    final currentDoc = ref.read(whiteboardProvider).document;
    if (widget.isOfflineTab) {
      if (currentDoc == null || (currentDoc.sessionId != null && currentDoc.sessionId!.isNotEmpty)) {
        ref.read(whiteboardProvider.notifier).initializeStandalone(
              defaultTitle: widget.sessionTitle ?? 'Offline Class Whiteboard',
              defaultTemplate: 'blank',
            );
      }
      return;
    }
    if (currentDoc == null || (widget.sessionId != null && currentDoc.sessionId != widget.sessionId)) {
      ref.read(whiteboardProvider.notifier).initializeForSession(
            widget.sessionId,
            defaultTitle: widget.sessionTitle ?? 'Whiteboard - Class 12 - A – Chemistry',
          );
    }
  }

  @override
  void didUpdateWidget(covariant WhiteboardWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isTabActive && !oldWidget.isTabActive) ||
        widget.sessionId != oldWidget.sessionId ||
        widget.isOfflineTab != oldWidget.isOfflineTab) {
      if (widget.isOfflineTab || widget.isEmbeddedInStage) {
        _showRightPanel = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureInitializedForMode();
      });
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _historySearchCtrl.dispose();
    _keyboardFocus.dispose();
    super.dispose();
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
          isOfflineTab: widget.isOfflineTab,
        ),
      ),
    );
  }

  Future<void> _promptEditBoardTitle({
    String? whiteboardId,
    String? currentTitle,
    String? currentDescription,
  }) async {
    final doc = ref.read(whiteboardProvider).document;
    final targetId = whiteboardId ?? doc?.id;
    if (targetId == null) return;
    if (whiteboardId == null && doc != null && !doc.myPermission.canManagePages) return;

    final titleCtrl = TextEditingController(text: currentTitle ?? doc?.title ?? '');
    final descCtrl = TextEditingController(text: currentDescription ?? '');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Board Details'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Session / Board Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (whiteboardId != null || currentDescription != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Topic / Class Notes (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, {'title': t, 'description': descCtrl.text.trim()});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result['title']!.isNotEmpty) {
      final ok = await ref.read(whiteboardProvider.notifier).updateBoardMeta(
            targetWhiteboardId: targetId,
            title: result['title'],
            description: (whiteboardId != null || currentDescription != null) ? result['description'] : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Updated "${result['title']}"' : 'Failed to update board')),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteBoard(String whiteboardId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Board Session?'),
        content: Text('Are you sure you want to delete "$title"? This archives the whiteboard and all its pages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await ref.read(whiteboardProvider.notifier).deleteBoard(whiteboardId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Deleted "$title"' : 'Unable to delete board')),
        );
      }
    }
  }

  Future<void> _createFreshBlankSession() async {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final title = 'Offline Session • $hh:$mm';
    final ok = await ref.read(whiteboardProvider.notifier).createNewBoard(
          title: title,
          templateType: 'blank',
          collaborationEnabled: !widget.isOfflineTab,
          forceStandalone: widget.isOfflineTab,
        );
    if (mounted) {
      if (MediaQuery.of(context).size.width < 950) {
        setState(() => _historyDrawerOpen = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Started fresh session "$title"' : 'Could not create session'),
          backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
        ),
      );
    }
  }

  String _formatHistoryTimestamp(dynamic raw) {
    if (raw == null) return 'Saved';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return 'Saved';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} • $hh:$mm';
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

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get cardBg => isDark ? const Color(0xFF13182C) : Colors.white;
  Color get barBg => isDark ? const Color(0xFF1A2238) : const Color(0xFFF8FAFC);
  Color get borderColor => isDark ? const Color(0xFF2E3852) : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get menuBg => isDark ? const Color(0xFF1E2235) : Colors.white;

  Widget _buildTopHeader() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFBFDBFE)),
          ),
          child: const Icon(Icons.draw_outlined, color: Color(0xFF2563EB), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open Whiteboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Text(
                'Collaborate, teach and explain in real time using an interactive whiteboard.',
                style: TextStyle(fontSize: 11.5, color: textSecondary),
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
              foregroundColor: textPrimary,
              side: BorderSide(color: borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wbState = ref.watch(whiteboardProvider);
    final doc = wbState.document;

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
              flex: widget.isEmbeddedInStage ? 1 : 8,
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(widget.isEmbeddedInStage ? 10 : 14),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
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
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Row(
                              children: [
                                if (screenW >= 950)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    width: _historyDrawerOpen ? 292 : 0,
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                      color: barBg,
                                      border: Border(
                                        right: BorderSide(color: _historyDrawerOpen ? borderColor : Colors.transparent),
                                      ),
                                    ),
                                    child: _historyDrawerOpen
                                        ? OverflowBox(
                                            minWidth: 292,
                                            maxWidth: 292,
                                            alignment: Alignment.topLeft,
                                            child: _buildWorkHistoryDrawer(wbState, doc, isOverlay: false),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                if (!_boardsSidebarCollapsed && !isCompact && !(_historyDrawerOpen && screenW < 1200))
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
                          if (_historyDrawerOpen && screenW < 950) ...[
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => setState(() => _historyDrawerOpen = false),
                                child: Container(color: Colors.black.withValues(alpha: 0.45)),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              width: screenW < 340 ? screenW * 0.9 : 296,
                              child: Material(
                                elevation: 12,
                                color: barBg,
                                child: _buildWorkHistoryDrawer(wbState, doc, isOverlay: true),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!widget.isEmbeddedInStage && !widget.isOfflineTab && _showRightPanel && !isCompact) ...[
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

        if (widget.isEmbeddedInStage) {
          return Focus(
            focusNode: _keyboardFocus,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: mainRow,
          );
        }

        return Focus(
          focusNode: _keyboardFocus,
          autofocus: !widget.isFullscreenRoute,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isFullscreenRoute && !widget.isOfflineTab) ...[
                _buildTopHeader(),
                const SizedBox(height: 10),
              ],

              // MAIN COLLABORATIVE WHITEBOARD + PARTICIPANTS ROW
              mainArea,
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
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.isEmbeddedInStage ? 10 : 14),
          topRight: Radius.circular(widget.isEmbeddedInStage ? 10 : 14),
        ),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if ((widget.isFullscreenRoute || widget.isEmbeddedInStage) && widget.onBackToClassroom != null) ...[
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                  backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: widget.onBackToClassroom,
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text('Exit Board', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
            ],
            Tooltip(
              message: _historyDrawerOpen ? 'Hide Work History Drawer' : 'Open Work History & Sessions Drawer',
              child: InkWell(
                onTap: () {
                  final nextOpen = !_historyDrawerOpen;
                  setState(() => _historyDrawerOpen = nextOpen);
                  if (nextOpen) {
                    ref.read(whiteboardProvider.notifier).refreshHistoryBoards();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _historyDrawerOpen
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _historyDrawerOpen ? const Color(0xFF2563EB) : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _historyDrawerOpen ? Icons.menu_open_rounded : Icons.history_rounded,
                        size: 15,
                        color: _historyDrawerOpen ? Colors.white : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'History (${wbState.sessionBoards.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _historyDrawerOpen ? Colors.white : textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.co_present_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 16),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _promptEditBoardTitle,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Text(
                    doc?.title ?? widget.sessionTitle ?? (widget.isOfflineTab ? 'Offline Class Whiteboard' : 'Whiteboard - Class 12 - A – Chemistry'),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  if (doc?.myPermission.canManagePages == true)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.edit_outlined, size: 13, color: textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Offline Class / Live indicator pill
            if (widget.isOfflineTab) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.45) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cast_for_education_rounded, size: 12, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                    const SizedBox(width: 4),
                    Text(
                      'Offline Class',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
              if (wbState.sessionBoards.length > 1) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Switch Saved Whiteboard',
                  color: menuBg,
                  onSelected: (wbId) => notifier.loadWhiteboard(wbId),
                  itemBuilder: (_) => wbState.sessionBoards.map((b) {
                    final bid = b['id']?.toString() ?? '';
                    final bTitle = (b['title'] ?? 'Class Whiteboard').toString();
                    final isCurrent = doc?.id == bid;
                    return PopupMenuItem<String>(
                      value: bid,
                      child: Row(
                        children: [
                          Icon(
                            isCurrent ? Icons.check_circle_rounded : Icons.dashboard_outlined,
                            size: 14,
                            color: isCurrent ? const Color(0xFF2563EB) : textSecondary,
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              bTitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 13, color: textSecondary),
                        const SizedBox(width: 4),
                        Text('Boards (${wbState.sessionBoards.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
                        Icon(Icons.arrow_drop_down_rounded, size: 15, color: textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF065F46).withValues(alpha: 0.4) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Live', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 8),
            saveBadge,
            if (!widget.isOfflineTab) ...[
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
            ],
            const SizedBox(width: 14),
            if (doc != null && doc.pages.isNotEmpty) ...[
              () {
                final curIdx = doc.pages.indexWhere((p) => p.id == wbState.activePageId);
                final activeIdx = curIdx >= 0 ? curIdx : 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconBtn(
                      Icons.chevron_left_rounded,
                      'Previous Page',
                      activeIdx > 0 ? () => notifier.selectPage(doc.pages[activeIdx - 1].id) : null,
                    ),
                    Text(
                      '${activeIdx + 1}/${doc.pages.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                    _iconBtn(
                      Icons.chevron_right_rounded,
                      'Next Page',
                      activeIdx < doc.pages.length - 1 ? () => notifier.selectPage(doc.pages[activeIdx + 1].id) : null,
                    ),
                    if (doc.myPermission.canManagePages)
                      _iconBtn(Icons.note_add_outlined, 'Add Board Page', () => notifier.addPage()),
                    const SizedBox(width: 6),
                  ],
                );
              }(),
            ],

            // Undo/Redo & Zoom controls
            _iconBtn(Icons.undo_rounded, 'Undo (Ctrl+Z)', wbState.undoStack.isNotEmpty ? notifier.undo : null),
            _iconBtn(Icons.redo_rounded, 'Redo (Ctrl+Shift+Z)', wbState.redoStack.isNotEmpty ? notifier.redo : null),
            _iconBtn(Icons.zoom_out_rounded, 'Zoom Out', notifier.zoomOut),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: notifier.resetView,
                child: Text('${(wbState.zoom * 100).round()}%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
              ),
            ),
            _iconBtn(Icons.zoom_in_rounded, 'Zoom In', notifier.zoomIn),
            _iconBtn(Icons.fit_screen_outlined, 'Reset / Fit View', notifier.resetView),
            const SizedBox(width: 10),

            // + New Board
            ElevatedButton.icon(
              onPressed: doc?.myPermission.canManagePages == false
                  ? null
                  : () => showDialog(
                        context: context,
                        builder: (_) => WhiteboardTemplatesDialog(forceStandalone: widget.isOfflineTab),
                      ),
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
              color: menuBg,
              icon: Icon(Icons.more_horiz_rounded, size: 18, color: textSecondary),
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
              itemBuilder: (_) => [
                PopupMenuItem(value: 'history', child: Text('Version History & Checkpoints', style: TextStyle(fontSize: 12, color: textPrimary))),
                PopupMenuItem(value: 'permissions', child: Text('Permissions & Lock Controls', style: TextStyle(fontSize: 12, color: textPrimary))),
                PopupMenuItem(value: 'spotlight', child: Text('Toggle Teacher Spotlight', style: TextStyle(fontSize: 12, color: textPrimary))),
                PopupMenuItem(value: 'boards_collapse', child: Text('Toggle Boards Panel', style: TextStyle(fontSize: 12, color: textPrimary))),
              ],
            ),
            if (!widget.isOfflineTab && !widget.isEmbeddedInStage)
              IconButton(
                tooltip: _showRightPanel ? 'Hide Meeting Panel' : 'Show Meeting Panel (Participants/Chat/Q&A)',
                icon: Icon(
                  _showRightPanel ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
                  size: 17,
                  color: _showRightPanel ? const Color(0xFF2563EB) : textSecondary,
                ),
                onPressed: () => setState(() => _showRightPanel = !_showRightPanel),
              ),
            IconButton(
              tooltip: widget.isFullscreenRoute ? 'Exit Fullscreen' : 'Fullscreen Whiteboard',
              icon: Icon(widget.isFullscreenRoute ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, size: 17, color: textSecondary),
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
        bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);
        txt = 'Saving...';
        icon = Icons.sync_rounded;
        break;
      case WhiteboardSaveState.unsaved:
        bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7);
        fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
        txt = 'Unsaved Changes';
        icon = Icons.edit_notifications_outlined;
        break;
      case WhiteboardSaveState.offline:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        txt = 'Offline';
        icon = Icons.cloud_off_rounded;
        break;
      case WhiteboardSaveState.syncing:
        bg = isDark ? const Color(0xFF075985).withValues(alpha: 0.35) : const Color(0xFFE0F2FE);
        fg = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7);
        txt = 'Syncing...';
        icon = Icons.cloud_sync_rounded;
        break;
      case WhiteboardSaveState.syncFailed:
        bg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEE2E2);
        fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
        txt = 'Sync Failed';
        icon = Icons.error_outline_rounded;
        break;
      case WhiteboardSaveState.saved:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
        fg = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
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
      decoration: BoxDecoration(
        color: barBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('Tool: ${s.activeTool.name.toUpperCase()}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            const SizedBox(width: 12),
            // Background quick switcher
            Text('Canvas:', style: TextStyle(fontSize: 11, color: textSecondary)),
            const SizedBox(width: 4),
            DropdownButtonHideUnderline(
              child: AppSearchableDropdown<WhiteboardBackgroundType>.fromMenuItems(
                value: activeBg,
                isDense: true,
                dropdownColor: menuBg,
                iconEnabledColor: textSecondary,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                items: WhiteboardBackgroundType.values
                    .map((bg) => DropdownMenuItem(
                          value: bg,
                          child: Text(
                            bg.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: bg == activeBg ? FontWeight.bold : FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (bg) {
                  if (bg != null) notifier.changePageBackground(bg);
                },
              ),
            ),
            const SizedBox(width: 14),
            if (s.activeTool == WhiteboardTool.eraser) ...[
              Text('Eraser Mode:', style: TextStyle(fontSize: 11, color: textSecondary)),
              const SizedBox(width: 6),
              for (final m in EraserMode.values)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text(m.name, style: TextStyle(fontSize: 10, color: s.eraserMode == m ? Colors.white : textPrimary)),
                    selected: s.eraserMode == m,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: isDark ? const Color(0xFF1E2235) : const Color(0xFFF1F5F9),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => notifier.setEraserMode(m),
                  ),
                ),
            ] else if (s.activeTool == WhiteboardTool.select && s.selectedObjectIds.isNotEmpty) ...[
              Text('${s.selectedObjectIds.length} selected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
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
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12),
                          foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
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
                          backgroundColor: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.25 : 0.12),
                          foregroundColor: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
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
                          backgroundColor: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.12),
                          foregroundColor: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                        ),
                        onPressed: () => _handleEditText(sel, Offset.zero),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }(),
              ],
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 13),
                label: const Text('Duplicate', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: textPrimary),
                onPressed: notifier.duplicateSelected,
              ),
              TextButton.icon(
                icon: const Icon(Icons.flip_to_front, size: 13),
                label: const Text('Forward', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: textPrimary),
                onPressed: notifier.bringForwardSelected,
              ),
              TextButton.icon(
                icon: const Icon(Icons.flip_to_back, size: 13),
                label: const Text('Back', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: textPrimary),
                onPressed: notifier.sendBackwardSelected,
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 13, color: Colors.red),
                label: const Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red)),
                onPressed: notifier.deleteSelectedObjects,
              ),
            ] else ...[
              Text('Opacity:', style: TextStyle(fontSize: 11, color: textSecondary)),
              SizedBox(
                width: 90,
                child: Slider(
                  value: s.opacity,
                  min: 0.2,
                  max: 1.0,
                  onChanged: notifier.setOpacity,
                ),
              ),
              Text('${(s.opacity * 100).round()}%', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(width: 10),
              if (s.activeTool == WhiteboardTool.rectangle ||
                  s.activeTool == WhiteboardTool.circle ||
                  s.activeTool == WhiteboardTool.ellipse ||
                  s.activeTool == WhiteboardTool.triangle ||
                  s.activeTool == WhiteboardTool.star ||
                  s.activeTool == WhiteboardTool.polygon) ...[
                Text('Fill:', style: TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => notifier.setFillColor(null),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2235) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: s.fillColor == null ? const Color(0xFF2563EB) : borderColor, width: 1.8),
                    ),
                    child: Icon(Icons.close, size: 11, color: textSecondary),
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
                        border: Border.all(color: s.fillColor == fc ? const Color(0xFF2563EB) : borderColor, width: 1.6),
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

  Widget _buildWorkHistoryDrawer(WhiteboardState s, WhiteboardDocument? doc, {required bool isOverlay}) {
    final notifier = ref.read(whiteboardProvider.notifier);
    final rawBoards = s.sessionBoards;
    final query = _historySearchQuery.trim().toLowerCase();

    final filtered = rawBoards.where((b) {
      final title = (b['title'] ?? '').toString().toLowerCase();
      final desc = (b['description'] ?? '').toString().toLowerCase();
      final template = (b['template_type'] ?? '').toString().toLowerCase();
      final hasSession = b['session_id'] != null && b['session_id'].toString().isNotEmpty;

      if (_historyFilter == 'Offline' && hasSession) return false;
      if (_historyFilter == 'Live' && !hasSession) return false;
      if (query.isNotEmpty && !title.contains(query) && !desc.contains(query) && !template.contains(query)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drawer Header + Hide button
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2235) : Colors.white,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, size: 17, color: Color(0xFF2563EB)),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work History & Sessions',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${filtered.length} of ${rawBoards.length} saved boards',
                      style: TextStyle(fontSize: 10.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh Sessions',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.refresh_rounded, size: 16, color: textSecondary),
                onPressed: () => notifier.refreshHistoryBoards(),
              ),
              IconButton(
                tooltip: 'Hide Drawer',
                visualDensity: VisualDensity.compact,
                icon: Icon(isOverlay ? Icons.close_rounded : Icons.chevron_left_rounded, size: 18, color: textSecondary),
                onPressed: () => setState(() => _historyDrawerOpen = false),
              ),
            ],
          ),
        ),

        // Create New Fresh Session bar
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => WhiteboardTemplatesDialog(forceStandalone: widget.isOfflineTab),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('New Fresh Session', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Instant Fresh Blank Canvas',
                child: OutlinedButton(
                  onPressed: _createFreshBlankSession,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    minimumSize: const Size(38, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Icon(Icons.note_add_outlined, size: 16),
                ),
              ),
            ],
          ),
        ),

        // Search input + Filter pills
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: _historySearchCtrl,
            onChanged: (v) => setState(() => _historySearchQuery = v),
            style: TextStyle(fontSize: 12, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Search old sessions...',
              hintStyle: TextStyle(fontSize: 11.5, color: textSecondary),
              prefixIcon: Icon(Icons.search_rounded, size: 16, color: textSecondary),
              suffixIcon: _historySearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 14, color: textSecondary),
                      onPressed: () {
                        _historySearchCtrl.clear();
                        setState(() => _historySearchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              for (final f in const ['All', 'Offline', 'Live']) ...[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: f == 'Live' ? 0 : 4),
                    child: InkWell(
                      onTap: () => setState(() => _historyFilter = f),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _historyFilter == f
                              ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.35 : 0.12)
                              : cardBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _historyFilter == f ? const Color(0xFF2563EB) : borderColor,
                          ),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: _historyFilter == f ? FontWeight.bold : FontWeight.w500,
                            color: _historyFilter == f
                                ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                : textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: borderColor),

        // Saved Boards / Sessions List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_clear_outlined, size: 32, color: textSecondary.withValues(alpha: 0.6)),
                        const SizedBox(height: 8),
                        Text(
                          'No matching board sessions',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start a new fresh session above to begin teaching.',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final wbId = (item['id'] ?? '').toString();
                    final title = (item['title'] ?? 'Class Whiteboard').toString();
                    final desc = (item['description'] ?? '').toString();
                    final hasSession = item['session_id'] != null && item['session_id'].toString().isNotEmpty;
                    final pageCount = (item['page_count'] as num?)?.toInt() ?? 1;
                    final objCount = (item['object_count'] as num?)?.toInt() ?? 0;
                    final updatedStr = _formatHistoryTimestamp(item['updated_at'] ?? item['created_at']);
                    final isActive = doc?.id == wbId;

                    return InkWell(
                      onTap: () async {
                        await notifier.loadWhiteboard(wbId);
                        if (isOverlay && mounted) {
                          setState(() => _historyDrawerOpen = false);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.28) : const Color(0xFFEFF6FF))
                              : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive ? const Color(0xFF2563EB) : borderColor,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                          : textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('Active', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                              ],
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, color: textSecondary),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: hasSession
                                        ? const Color(0xFF10B981).withValues(alpha: 0.14)
                                        : const Color(0xFF2563EB).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    hasSession ? 'Live Class' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: hasSession ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$pageCount pg • $objCount items',
                                  style: TextStyle(fontSize: 10, color: textSecondary),
                                ),
                                Text(
                                  updatedStr,
                                  style: TextStyle(fontSize: 10, color: textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Divider(height: 1, color: borderColor.withValues(alpha: 0.6)),
                            const SizedBox(height: 4),
                            // Full CRUD + Rework + Share row
                            Row(
                              children: [
                                Flexible(
                                  child: InkWell(
                                    onTap: () async {
                                      await notifier.loadWhiteboard(wbId);
                                      if (isOverlay && mounted) {
                                        setState(() => _historyDrawerOpen = false);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(5),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_note_rounded,
                                            size: 14,
                                            color: isActive ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              isActive ? 'Editing' : 'Rework',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: isActive ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                _drawerActionIcon(
                                  Icons.drive_file_rename_outline_rounded,
                                  'Rename / Edit',
                                  () => _promptEditBoardTitle(
                                    whiteboardId: wbId,
                                    currentTitle: title,
                                    currentDescription: desc,
                                  ),
                                ),
                                _drawerActionIcon(
                                  Icons.copy_rounded,
                                  'Duplicate Copy',
                                  () async {
                                    final ok = await notifier.duplicateBoard(wbId, openAfter: true);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(ok ? 'Duplicated "$title" for rework!' : 'Failed to duplicate board')),
                                      );
                                    }
                                  },
                                ),
                                _drawerActionIcon(
                                  Icons.share_outlined,
                                  'Share Board',
                                  () => showDialog(
                                    context: context,
                                    builder: (_) => WhiteboardShareDialog(whiteboardId: wbId, boardTitle: title),
                                  ),
                                ),
                                _drawerActionIcon(
                                  Icons.download_outlined,
                                  'Export Board',
                                  () => showDialog(
                                    context: context,
                                    builder: (_) => WhiteboardExportDialog(whiteboardId: wbId, boardTitle: title),
                                  ),
                                ),
                                _drawerActionIcon(
                                  Icons.delete_outline_rounded,
                                  'Delete Board',
                                  () => _confirmAndDeleteBoard(wbId, title),
                                  color: Colors.redAccent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _drawerActionIcon(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 15, color: color ?? textSecondary),
        ),
      ),
    );
  }

  Widget _buildBoardsPageSidebar(WhiteboardState s, WhiteboardDocument? doc) {
    final pages = doc?.pages ?? [];
    final notifier = ref.read(whiteboardProvider.notifier);

    return Container(
      width: 146,
      decoration: BoxDecoration(
        color: barBg,
        border: Border(right: BorderSide(color: borderColor)),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _boardsSidebarCollapsed = true),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textSecondary),
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
                      color: cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? const Color(0xFF2563EB) : borderColor,
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
                            color: active ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF)) : cardBg,
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
                                    color: active ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)) : textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (p.isLocked)
                                const Icon(Icons.lock_outline, size: 11, color: Color(0xFFF59E0B)),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                color: menuBg,
                                icon: Icon(Icons.more_vert, size: 13, color: textSecondary),
                                onSelected: (act) async {
                                  if (act == 'dup') {
                                    notifier.duplicateCurrentPage(p.id);
                                  } else if (act == 'lock') {
                                    notifier.togglePageLock(p.id);
                                  } else if (act == 'del') {
                                    notifier.deletePage(p.id);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'dup', child: Text('Duplicate Page', style: TextStyle(fontSize: 11, color: textPrimary))),
                                  PopupMenuItem(value: 'lock', child: Text('Toggle Lock', style: TextStyle(fontSize: 11, color: textPrimary))),
                                  const PopupMenuItem(value: 'del', child: Text('Delete Page', style: TextStyle(fontSize: 11, color: Colors.red))),
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
                side: BorderSide(color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFBFDBFE)),
                backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : Colors.transparent,
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
      decoration: BoxDecoration(
        color: barBg,
        border: Border(right: BorderSide(color: borderColor)),
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
                      color: s.activeTool == item['tool'] ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
            ],
            Divider(height: 12, color: borderColor),
            Tooltip(
              message: 'Undo',
              child: InkWell(
                onTap: s.undoStack.isNotEmpty ? notifier.undo : null,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.undo_rounded,
                    size: 17,
                    color: s.undoStack.isNotEmpty ? textPrimary : textSecondary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Redo',
              child: InkWell(
                onTap: s.redoStack.isNotEmpty ? notifier.redo : null,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.redo_rounded,
                    size: 17,
                    color: s.redoStack.isNotEmpty ? textPrimary : textSecondary.withValues(alpha: 0.4),
                  ),
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
      isDark ? Colors.white : const Color(0xFF0F172A),
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
                color: menuBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08), blurRadius: 12, offset: const Offset(0, 4)),
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
                            color: s.strokeColor == c ? const Color(0xFF2563EB) : (c == Colors.white || c == const Color(0xFF0F172A) ? borderColor : Colors.transparent),
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 18, color: borderColor),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<double>.fromMenuItems(
                      value: [2.0, 3.0, 5.0, 8.0].contains(s.strokeWidth) ? s.strokeWidth : 3.0,
                      isDense: true,
                      dropdownColor: menuBg,
                      iconEnabledColor: textSecondary,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary),
                      items: [2.0, 3.0, 5.0, 8.0]
                          .map((w) => DropdownMenuItem(
                                value: w,
                                child: Text(
                                  '${w.toInt()}px',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) notifier.setStrokeWidth(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 18, color: borderColor),
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
                            color: s.strokeWidth == w ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
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
                color: menuBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => notifier.setTool(WhiteboardTool.pen),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(Icons.edit_outlined, size: 16, color: s.activeTool == WhiteboardTool.pen ? const Color(0xFF2563EB) : textSecondary),
                    ),
                  ),
                  Container(width: 1, height: 16, color: borderColor),
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
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(Icons.delete_outline_rounded, size: 16, color: textSecondary),
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

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 17,
            color: onTap != null
                ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))
                : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
          ),
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
        foregroundColor: textPrimary,
        side: BorderSide(color: borderColor),
        backgroundColor: isDark ? const Color(0xFF1E2235) : Colors.transparent,
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
  final bool isOfflineTab;

  const WhiteboardScreen({
    super.key,
    this.sessionId,
    this.sessionTitle,
    this.onEndClass,
    this.onLeaveClass,
    this.isOfflineTab = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: WhiteboardWorkspace(
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            isFullscreenRoute: true,
            isOfflineTab: isOfflineTab,
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
