import 'dart:math' as math;
import 'package:flutter/material.dart';

enum WhiteboardTool {
  select,
  pan,
  pen,
  pencil,
  highlighter,
  laser,
  eraser,
  line,
  arrow,
  doubleArrow,
  curvedLine,
  rectangle,
  circle,
  ellipse,
  triangle,
  polygon,
  star,
  freeformShape,
  text,
  stickyNote,
  image,
  equation,
  connector,
  measurement,
  studentZone,
}

enum EraserMode { stroke, object, area }

enum WhiteboardBackgroundType {
  plain,
  lightGrid,
  darkGrid,
  dotted,
  ruled,
  graph,
  engineering,
  music,
  customImage,
}

extension WhiteboardBackgroundTypeExt on WhiteboardBackgroundType {
  String get apiValue {
    switch (this) {
      case WhiteboardBackgroundType.plain:
        return 'plain';
      case WhiteboardBackgroundType.lightGrid:
        return 'light_grid';
      case WhiteboardBackgroundType.darkGrid:
        return 'dark_grid';
      case WhiteboardBackgroundType.dotted:
        return 'dotted';
      case WhiteboardBackgroundType.ruled:
        return 'ruled';
      case WhiteboardBackgroundType.graph:
        return 'graph';
      case WhiteboardBackgroundType.engineering:
        return 'engineering';
      case WhiteboardBackgroundType.music:
        return 'music';
      case WhiteboardBackgroundType.customImage:
        return 'custom_image';
    }
  }

  String get label {
    switch (this) {
      case WhiteboardBackgroundType.plain:
        return 'Plain White';
      case WhiteboardBackgroundType.lightGrid:
        return 'Light Grid';
      case WhiteboardBackgroundType.darkGrid:
        return 'Dark Grid';
      case WhiteboardBackgroundType.dotted:
        return 'Dotted Grid';
      case WhiteboardBackgroundType.ruled:
        return 'Ruled Notebook';
      case WhiteboardBackgroundType.graph:
        return 'Graph Paper';
      case WhiteboardBackgroundType.engineering:
        return 'Engineering Grid';
      case WhiteboardBackgroundType.music:
        return 'Music Staff';
      case WhiteboardBackgroundType.customImage:
        return 'Custom Image';
    }
  }

  static WhiteboardBackgroundType fromApi(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'light_grid':
        return WhiteboardBackgroundType.lightGrid;
      case 'dark_grid':
        return WhiteboardBackgroundType.darkGrid;
      case 'dotted':
        return WhiteboardBackgroundType.dotted;
      case 'ruled':
        return WhiteboardBackgroundType.ruled;
      case 'graph':
        return WhiteboardBackgroundType.graph;
      case 'engineering':
        return WhiteboardBackgroundType.engineering;
      case 'music':
        return WhiteboardBackgroundType.music;
      case 'custom_image':
        return WhiteboardBackgroundType.customImage;
      default:
        return WhiteboardBackgroundType.plain;
    }
  }
}

enum WhiteboardSaveState { saved, saving, unsaved, offline, syncing, syncFailed }

class WhiteboardColorHelper {
  static Color parse(String? hex, {Color fallback = const Color(0xFF0F172A)}) {
    if (hex == null || hex.isEmpty) return fallback;
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 3) {
      clean = clean.split('').map((c) => '$c$c').join();
    }
    if (clean.length == 6) clean = 'FF$clean';
    if (clean.length != 8) return fallback;
    final val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  static String toHex(Color color) {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${argb.substring(2)}';
  }
}

class WhiteboardObject {
  final String id;
  final String pageId;
  final String type;
  final Map<String, dynamic> data;
  final int zIndex;
  final bool isLocked;
  final String? createdBy;

  const WhiteboardObject({
    required this.id,
    required this.pageId,
    required this.type,
    required this.data,
    this.zIndex = 0,
    this.isLocked = false,
    this.createdBy,
  });

  factory WhiteboardObject.fromJson(Map<String, dynamic> json, {String fallbackPageId = ''}) {
    return WhiteboardObject(
      id: (json['id'] ?? json['object_id'] ?? '').toString(),
      pageId: (json['page_id'] ?? fallbackPageId).toString(),
      type: (json['type'] ?? json['object_type'] ?? 'stroke').toString(),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'])
          : (json['object_data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(json['object_data'])
              : <String, dynamic>{}),
      zIndex: (json['z_index'] as num?)?.toInt() ?? 0,
      isLocked: json['is_locked'] == true,
      createdBy: json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'page_id': pageId,
        'type': type,
        'data': data,
        'z_index': zIndex,
        'is_locked': isLocked,
        if (createdBy != null) 'created_by': createdBy,
      };

  WhiteboardObject copyWith({
    String? id,
    String? pageId,
    String? type,
    Map<String, dynamic>? data,
    int? zIndex,
    bool? isLocked,
    String? createdBy,
  }) {
    return WhiteboardObject(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      type: type ?? this.type,
      data: data ?? Map<String, dynamic>.from(this.data),
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Color get color => WhiteboardColorHelper.parse(data['color']?.toString());
  Color? get bgColor => data['bgColor'] != null
      ? WhiteboardColorHelper.parse(data['bgColor'].toString())
      : (data['fillColor'] != null ? WhiteboardColorHelper.parse(data['fillColor'].toString()) : null);
  Color? get borderColor =>
      data['borderColor'] != null ? WhiteboardColorHelper.parse(data['borderColor'].toString()) : null;
  double get strokeWidth => (data['strokeWidth'] as num?)?.toDouble() ?? 3.0;
  double get opacity => ((data['opacity'] as num?)?.toDouble() ?? 1.0).clamp(0.05, 1.0);
  double get rotation => (data['rotation'] as num?)?.toDouble() ?? 0.0;
  String get strokeStyle => (data['strokeStyle'] ?? 'solid').toString();

  List<Offset> get points {
    final raw = data['points'] as List? ?? const [];
    final out = <Offset>[];
    for (final item in raw) {
      if (item is List && item.length >= 2) {
        out.add(Offset((item[0] as num).toDouble(), (item[1] as num).toDouble()));
      } else if (item is Map) {
        out.add(Offset((item['x'] as num).toDouble(), (item['y'] as num).toDouble()));
      }
    }
    return out;
  }

  List<double> get pressures {
    final raw = data['pressures'] as List? ?? const [];
    return raw.map((e) => (e as num).toDouble()).toList();
  }

  bool get isPointBased =>
      type == 'stroke' || type == 'pencil' || type == 'highlighter' || type == 'freeform_shape';

  bool get isLineBased =>
      type == 'line' ||
      type == 'arrow' ||
      type == 'double_arrow' ||
      type == 'curved_line' ||
      type == 'connector' ||
      type == 'measurement';

  Rect getBounds() {
    if (isPointBased) {
      final pts = points;
      if (pts.isEmpty) return const Rect.fromLTWH(0, 0, 10, 10);
      double minX = pts.first.dx, maxX = pts.first.dx;
      double minY = pts.first.dy, maxY = pts.first.dy;
      for (final p in pts) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      final pad = math.max(8.0, strokeWidth);
      return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
    }
    if (isLineBased) {
      final x1 = (data['x1'] as num?)?.toDouble() ?? 0;
      final y1 = (data['y1'] as num?)?.toDouble() ?? 0;
      final x2 = (data['x2'] as num?)?.toDouble() ?? x1 + 40;
      final y2 = (data['y2'] as num?)?.toDouble() ?? y1;
      return Rect.fromLTRB(
        math.min(x1, x2) - 8,
        math.min(y1, y2) - 8,
        math.max(x1, x2) + 8,
        math.max(y1, y2) + 8,
      );
    }
    final x = (data['x'] as num?)?.toDouble() ?? 0;
    final y = (data['y'] as num?)?.toDouble() ?? 0;
    final w = (data['width'] as num?)?.toDouble() ?? 120;
    final h = (data['height'] as num?)?.toDouble() ?? (type == 'circle' ? w : 60);
    return Rect.fromLTWH(x, y, w.abs() < 12 ? 12 : w, h.abs() < 12 ? 12 : h);
  }

  bool hitTest(Offset pos, {double tolerance = 10.0}) {
    if (isPointBased) {
      final pts = points;
      for (final p in pts) {
        if ((p - pos).distance <= tolerance + strokeWidth) return true;
      }
      return false;
    }
    if (isLineBased) {
      final a = Offset((data['x1'] as num?)?.toDouble() ?? 0, (data['y1'] as num?)?.toDouble() ?? 0);
      final b = Offset((data['x2'] as num?)?.toDouble() ?? 0, (data['y2'] as num?)?.toDouble() ?? 0);

      // Check badge label rectangle if present (or centered relationship zone)
      final labelStr = (data['label'] ?? data['text'])?.toString();
      final mid = (type == 'curved_line' || type == 'connector')
          ? Offset((a.dx + b.dx) / 2, (math.min(a.dy, b.dy) - 45 + (a.dy + b.dy) / 2) / 2)
          : Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      if (labelStr != null && labelStr.isNotEmpty) {
        final badgeRect = Rect.fromCenter(center: mid, width: 120, height: 36);
        if (badgeRect.inflate(tolerance).contains(pos)) return true;
      }

      // Check points along quadratic bezier curve for curved lines and connectors
      if (type == 'curved_line' || type == 'connector') {
        final ctrl = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 45);
        for (double t = 0; t <= 1.0; t += 0.08) {
          final oneMinusT = 1.0 - t;
          final curvePoint = Offset(
            oneMinusT * oneMinusT * a.dx + 2 * oneMinusT * t * ctrl.dx + t * t * b.dx,
            oneMinusT * oneMinusT * a.dy + 2 * oneMinusT * t * ctrl.dy + t * t * b.dy,
          );
          if ((pos - curvePoint).distance <= tolerance + strokeWidth) return true;
        }
      }

      return _distPointToSegment(pos, a, b) <= tolerance + strokeWidth;
    }
    return getBounds().inflate(tolerance).contains(pos);
  }

  static double _distPointToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq).clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * dx, a.dy + t * dy);
    return (p - proj).distance;
  }

  WhiteboardObject movedBy(double dx, double dy) {
    if (isLocked) return this;
    final next = Map<String, dynamic>.from(data);
    if (isPointBased) {
      next['points'] = points.map((p) => [p.dx + dx, p.dy + dy]).toList();
    } else if (isLineBased) {
      next['x1'] = ((next['x1'] as num?)?.toDouble() ?? 0) + dx;
      next['y1'] = ((next['y1'] as num?)?.toDouble() ?? 0) + dy;
      next['x2'] = ((next['x2'] as num?)?.toDouble() ?? 0) + dx;
      next['y2'] = ((next['y2'] as num?)?.toDouble() ?? 0) + dy;
      if (next['cx'] != null) next['cx'] = (next['cx'] as num).toDouble() + dx;
      if (next['cy'] != null) next['cy'] = (next['cy'] as num).toDouble() + dy;
    } else {
      next['x'] = ((next['x'] as num?)?.toDouble() ?? 0) + dx;
      next['y'] = ((next['y'] as num?)?.toDouble() ?? 0) + dy;
    }
    return copyWith(data: next);
  }

  WhiteboardObject resizedTo(Rect newRect) {
    if (isLocked) return this;
    final oldRect = getBounds();
    final next = Map<String, dynamic>.from(data);
    if (isPointBased) {
      final ow = oldRect.width == 0 ? 1.0 : oldRect.width;
      final oh = oldRect.height == 0 ? 1.0 : oldRect.height;
      final sx = newRect.width / ow;
      final sy = newRect.height / oh;
      next['points'] = points
          .map((p) => [
                newRect.left + (p.dx - oldRect.left) * sx,
                newRect.top + (p.dy - oldRect.top) * sy,
              ])
          .toList();
    } else if (isLineBased) {
      next['x1'] = newRect.left;
      next['y1'] = newRect.top;
      next['x2'] = newRect.right;
      next['y2'] = newRect.bottom;
    } else {
      next['x'] = newRect.left;
      next['y'] = newRect.top;
      next['width'] = math.max(24.0, newRect.width);
      next['height'] = math.max(24.0, newRect.height);
    }
    return copyWith(data: next);
  }
}

class WhiteboardPage {
  final String id;
  final String whiteboardId;
  final String title;
  final int pageOrder;
  final WhiteboardBackgroundType backgroundType;
  final Map<String, dynamic> backgroundConfig;
  final Map<String, dynamic> canvasConfig;
  final bool isLocked;
  final List<WhiteboardObject> objects;

  const WhiteboardPage({
    required this.id,
    required this.whiteboardId,
    required this.title,
    required this.pageOrder,
    this.backgroundType = WhiteboardBackgroundType.plain,
    this.backgroundConfig = const {},
    this.canvasConfig = const {'width': 2400, 'height': 1600},
    this.isLocked = false,
    this.objects = const [],
  });

  factory WhiteboardPage.fromJson(Map<String, dynamic> json) {
    final pid = (json['id'] ?? '').toString();
    return WhiteboardPage(
      id: pid,
      whiteboardId: (json['whiteboard_id'] ?? '').toString(),
      title: (json['title'] ?? 'Page 1').toString(),
      pageOrder: (json['page_order'] as num?)?.toInt() ?? 1,
      backgroundType: WhiteboardBackgroundTypeExt.fromApi(json['background_type']?.toString()),
      backgroundConfig: json['background_config'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['background_config'])
          : const {},
      canvasConfig: json['canvas_config'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['canvas_config'])
          : const {'width': 2400, 'height': 1600},
      isLocked: json['is_locked'] == true,
      objects: (json['objects'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((o) => WhiteboardObject.fromJson(o, fallbackPageId: pid))
          .toList(),
    );
  }

  WhiteboardPage copyWith({
    String? title,
    int? pageOrder,
    WhiteboardBackgroundType? backgroundType,
    Map<String, dynamic>? backgroundConfig,
    bool? isLocked,
    List<WhiteboardObject>? objects,
  }) {
    return WhiteboardPage(
      id: id,
      whiteboardId: whiteboardId,
      title: title ?? this.title,
      pageOrder: pageOrder ?? this.pageOrder,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundConfig: backgroundConfig ?? this.backgroundConfig,
      canvasConfig: canvasConfig,
      isLocked: isLocked ?? this.isLocked,
      objects: objects ?? this.objects,
    );
  }
}

class WhiteboardPermissionInfo {
  final bool allowed;
  final String permission;
  final bool canEdit;
  final bool canManagePages;
  final bool canManagePermissions;
  final bool canExport;
  final Rect? assignedArea;

  const WhiteboardPermissionInfo({
    this.allowed = true,
    this.permission = 'OWNER',
    this.canEdit = true,
    this.canManagePages = true,
    this.canManagePermissions = true,
    this.canExport = true,
    this.assignedArea,
  });

  factory WhiteboardPermissionInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WhiteboardPermissionInfo();
    Rect? rect;
    final area = json['assigned_area'];
    if (area is Map) {
      rect = Rect.fromLTWH(
        (area['x'] as num?)?.toDouble() ?? 0,
        (area['y'] as num?)?.toDouble() ?? 0,
        (area['width'] as num?)?.toDouble() ?? 300,
        (area['height'] as num?)?.toDouble() ?? 200,
      );
    }
    return WhiteboardPermissionInfo(
      allowed: json['allowed'] != false,
      permission: (json['permission'] ?? 'OWNER').toString(),
      canEdit: json['can_edit'] != false,
      canManagePages: json['can_manage_pages'] == true,
      canManagePermissions: json['can_manage_permissions'] == true,
      canExport: json['can_export'] != false,
      assignedArea: rect,
    );
  }
}

class WhiteboardVersionItem {
  final String id;
  final int revision;
  final String versionName;
  final bool isCheckpoint;
  final String createdByName;
  final String createdAt;

  const WhiteboardVersionItem({
    required this.id,
    required this.revision,
    required this.versionName,
    required this.isCheckpoint,
    required this.createdByName,
    required this.createdAt,
  });

  factory WhiteboardVersionItem.fromJson(Map<String, dynamic> json) {
    return WhiteboardVersionItem(
      id: (json['id'] ?? '').toString(),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      versionName: (json['version_name'] ?? 'Version').toString(),
      isCheckpoint: json['is_checkpoint'] == true,
      createdByName: (json['created_by_name'] ?? 'Teacher').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class WhiteboardCollaborator {
  final String userId;
  final String name;
  final String role;
  final Color color;

  const WhiteboardCollaborator({
    required this.userId,
    required this.name,
    required this.role,
    required this.color,
  });

  factory WhiteboardCollaborator.fromJson(Map<String, dynamic> json) {
    return WhiteboardCollaborator(
      userId: (json['user_id'] ?? '').toString(),
      name: (json['name'] ?? 'User').toString(),
      role: (json['role'] ?? 'student').toString(),
      color: WhiteboardColorHelper.parse(json['color']?.toString(), fallback: const Color(0xFF2563EB)),
    );
  }
}

class WhiteboardRemoteCursor {
  final String userId;
  final String name;
  final Color color;
  final double x;
  final double y;
  final String tool;
  final String? pageId;
  final DateTime updatedAt;

  const WhiteboardRemoteCursor({
    required this.userId,
    required this.name,
    required this.color,
    required this.x,
    required this.y,
    required this.tool,
    this.pageId,
    required this.updatedAt,
  });
}

class WhiteboardLaserPoint {
  final Offset position;
  final Color color;
  final DateTime createdAt;

  const WhiteboardLaserPoint({
    required this.position,
    required this.color,
    required this.createdAt,
  });
}

class WhiteboardTemplateItem {
  final String id;
  final String name;
  final String category;
  final String backgroundType;
  final String description;

  const WhiteboardTemplateItem({
    required this.id,
    required this.name,
    required this.category,
    required this.backgroundType,
    required this.description,
  });

  factory WhiteboardTemplateItem.fromJson(Map<String, dynamic> json) {
    return WhiteboardTemplateItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? 'General').toString(),
      backgroundType: (json['background_type'] ?? 'plain').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class WhiteboardShareItem {
  final String id;
  final String shareType;
  final String targetLabel;
  final String accessLevel;
  final String shareToken;
  final String? expiresAt;
  final String createdAt;

  const WhiteboardShareItem({
    required this.id,
    required this.shareType,
    required this.targetLabel,
    required this.accessLevel,
    required this.shareToken,
    this.expiresAt,
    required this.createdAt,
  });

  factory WhiteboardShareItem.fromJson(Map<String, dynamic> json) {
    return WhiteboardShareItem(
      id: (json['id'] ?? '').toString(),
      shareType: (json['share_type'] ?? 'class').toString(),
      targetLabel: (json['target_label'] ?? '').toString(),
      accessLevel: (json['access_level'] ?? 'VIEW').toString(),
      shareToken: (json['share_token'] ?? '').toString(),
      expiresAt: json['expires_at']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class WhiteboardDocument {
  final String id;
  final String? sessionId;
  final String title;
  final String description;
  final String status;
  final int currentRevision;
  final bool teacherOnlyMode;
  final bool collaborationEnabled;
  final bool presentationMode;
  final Map<String, dynamic> defaultPermissions;
  final String templateType;
  final WhiteboardPermissionInfo myPermission;
  final List<WhiteboardPage> pages;
  final List<WhiteboardVersionItem> versions;
  final List<WhiteboardCollaborator> activeCollaborators;

  const WhiteboardDocument({
    required this.id,
    this.sessionId,
    required this.title,
    this.description = '',
    this.status = 'ACTIVE',
    this.currentRevision = 1,
    this.teacherOnlyMode = false,
    this.collaborationEnabled = true,
    this.presentationMode = false,
    this.defaultPermissions = const {},
    this.templateType = 'blank',
    this.myPermission = const WhiteboardPermissionInfo(),
    this.pages = const [],
    this.versions = const [],
    this.activeCollaborators = const [],
  });

  factory WhiteboardDocument.fromJson(Map<String, dynamic> json) {
    return WhiteboardDocument(
      id: (json['id'] ?? '').toString(),
      sessionId: json['session_id']?.toString(),
      title: (json['title'] ?? 'Class Whiteboard').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      currentRevision: (json['current_revision'] as num?)?.toInt() ?? 1,
      teacherOnlyMode: json['teacher_only_mode'] == true,
      collaborationEnabled: json['collaboration_enabled'] != false,
      presentationMode: json['presentation_mode'] == true,
      defaultPermissions: json['default_permissions'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['default_permissions'])
          : const {},
      templateType: (json['template_type'] ?? 'blank').toString(),
      myPermission: WhiteboardPermissionInfo.fromJson(json['my_permission'] as Map<String, dynamic>?),
      pages: (json['pages'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WhiteboardPage.fromJson)
          .toList(),
      versions: (json['versions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WhiteboardVersionItem.fromJson)
          .toList(),
      activeCollaborators: (json['active_collaborators'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(WhiteboardCollaborator.fromJson)
          .toList(),
    );
  }

  WhiteboardDocument copyWith({
    String? title,
    int? currentRevision,
    bool? teacherOnlyMode,
    bool? collaborationEnabled,
    bool? presentationMode,
    Map<String, dynamic>? defaultPermissions,
    WhiteboardPermissionInfo? myPermission,
    List<WhiteboardPage>? pages,
    List<WhiteboardVersionItem>? versions,
    List<WhiteboardCollaborator>? activeCollaborators,
  }) {
    return WhiteboardDocument(
      id: id,
      sessionId: sessionId,
      title: title ?? this.title,
      description: description,
      status: status,
      currentRevision: currentRevision ?? this.currentRevision,
      teacherOnlyMode: teacherOnlyMode ?? this.teacherOnlyMode,
      collaborationEnabled: collaborationEnabled ?? this.collaborationEnabled,
      presentationMode: presentationMode ?? this.presentationMode,
      defaultPermissions: defaultPermissions ?? this.defaultPermissions,
      templateType: templateType,
      myPermission: myPermission ?? this.myPermission,
      pages: pages ?? this.pages,
      versions: versions ?? this.versions,
      activeCollaborators: activeCollaborators ?? this.activeCollaborators,
    );
  }
}

class WhiteboardUndoEntry {
  final String pageId;
  final String actionType; // 'create', 'update', 'delete', 'clear_page'
  final List<WhiteboardObject> beforeObjects;
  final List<WhiteboardObject> afterObjects;

  const WhiteboardUndoEntry({
    required this.pageId,
    required this.actionType,
    required this.beforeObjects,
    required this.afterObjects,
  });
}
