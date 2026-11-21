import 'package:flutter/foundation.dart';
import '../../../../services/api_service.dart';
import '../models/whiteboard_models.dart';

class WhiteboardApiService {
  final ApiService _api = ApiService();

  Future<List<WhiteboardTemplateItem>> fetchTemplates() async {
    try {
      final res = await _api.get('/whiteboards/templates');
      final list = res['data'] as List? ?? [];
      return list.whereType<Map<String, dynamic>>().map(WhiteboardTemplateItem.fromJson).toList();
    } catch (e) {
      debugPrint('[WhiteboardApiService] fetchTemplates error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> listWhiteboards({String? sessionId}) async {
    try {
      final res = await _api.get(
        '/whiteboards',
        query: sessionId != null && sessionId.isNotEmpty ? {'session_id': sessionId} : null,
        useCache: false,
      );
      final list = res['data'] as List? ?? [];
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[WhiteboardApiService] listWhiteboards error: $e');
      return [];
    }
  }

  Future<WhiteboardDocument?> createWhiteboard({
    String? sessionId,
    required String title,
    String templateType = 'blank',
    bool collaborationEnabled = true,
  }) async {
    try {
      final res = await _api.post('/whiteboards', {
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
        'title': title,
        'template_type': templateType,
        'collaboration_enabled': collaborationEnabled,
      });
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardDocument.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] createWhiteboard error: $e');
    }
    return null;
  }

  Future<WhiteboardDocument?> fetchWhiteboard(String whiteboardId) async {
    try {
      final res = await _api.get('/whiteboards/$whiteboardId', useCache: false);
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardDocument.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] fetchWhiteboard error: $e');
    }
    return null;
  }

  Future<WhiteboardDocument?> updateWhiteboardMeta(
    String whiteboardId, {
    String? title,
    bool? collaborationEnabled,
    bool? presentationMode,
    bool? teacherOnlyMode,
    Map<String, dynamic>? defaultPermissions,
  }) async {
    try {
      final res = await _api.patch('/whiteboards/$whiteboardId', {
        if (title != null) 'title': title,
        if (collaborationEnabled != null) 'collaboration_enabled': collaborationEnabled,
        if (presentationMode != null) 'presentation_mode': presentationMode,
        if (teacherOnlyMode != null) 'teacher_only_mode': teacherOnlyMode,
        if (defaultPermissions != null) 'default_permissions': defaultPermissions,
      });
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardDocument.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] updateWhiteboardMeta error: $e');
    }
    return null;
  }

  Future<WhiteboardPage?> createPage(
    String whiteboardId, {
    String? title,
    String backgroundType = 'plain',
  }) async {
    try {
      final res = await _api.post('/whiteboards/$whiteboardId/pages', {
        if (title != null) 'title': title,
        'background_type': backgroundType,
      });
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardPage.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] createPage error: $e');
    }
    return null;
  }

  Future<WhiteboardPage?> updatePage(
    String whiteboardId,
    String pageId, {
    String? title,
    String? backgroundType,
    bool? isLocked,
  }) async {
    try {
      final res = await _api.patch('/whiteboards/$whiteboardId/pages/$pageId', {
        if (title != null) 'title': title,
        if (backgroundType != null) 'background_type': backgroundType,
        if (isLocked != null) 'is_locked': isLocked,
      });
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardPage.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] updatePage error: $e');
    }
    return null;
  }

  Future<bool> deletePage(String whiteboardId, String pageId) async {
    try {
      final res = await _api.delete('/whiteboards/$whiteboardId/pages/$pageId');
      return res['success'] == true;
    } catch (e) {
      debugPrint('[WhiteboardApiService] deletePage error: $e');
      return false;
    }
  }

  Future<WhiteboardPage?> duplicatePage(String whiteboardId, String pageId) async {
    try {
      final res = await _api.post('/whiteboards/$whiteboardId/pages/$pageId/duplicate', {});
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardPage.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] duplicatePage error: $e');
    }
    return null;
  }

  Future<bool> reorderPages(String whiteboardId, List<String> pageIds) async {
    try {
      final res = await _api.post('/whiteboards/$whiteboardId/pages/reorder', {'page_ids': pageIds});
      return res['success'] == true;
    } catch (e) {
      debugPrint('[WhiteboardApiService] reorderPages error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> applyOperation({
    required String whiteboardId,
    required String pageId,
    required String operationId,
    required String operationType,
    String? objectId,
    String? objectType,
    required Map<String, dynamic> operationData,
  }) async {
    try {
      final res = await _api.post('/whiteboards/$whiteboardId/operations', {
        'page_id': pageId,
        'operation_id': operationId,
        'operation_type': operationType,
        if (objectId != null) 'object_id': objectId,
        if (objectType != null) 'object_type': objectType,
        'operation_data': operationData,
      });
      return res['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[WhiteboardApiService] applyOperation error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> syncSince(String whiteboardId, int sinceRevision) async {
    try {
      final res = await _api.get(
        '/whiteboards/$whiteboardId/sync',
        query: {'since_revision': sinceRevision},
        useCache: false,
      );
      return res['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[WhiteboardApiService] syncSince error: $e');
      return null;
    }
  }

  Future<WhiteboardVersionItem?> createCheckpoint(
    String whiteboardId, {
    required String versionName,
    bool isCheckpoint = true,
  }) async {
    try {
      final res = await _api.post('/whiteboards/$whiteboardId/versions', {
        'version_name': versionName,
        'is_checkpoint': isCheckpoint,
      });
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardVersionItem.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] createCheckpoint error: $e');
    }
    return null;
  }

  Future<WhiteboardDocument?> restoreVersion(String whiteboardId, String versionId) async {
    try {
      final res = await _api.post('/whiteboards/$whiteboardId/versions/$versionId/restore', {});
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardDocument.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] restoreVersion error: $e');
    }
    return null;
  }

  Future<bool> setPermission(
    String whiteboardId, {
    String? targetUserId,
    String? targetRole,
    required String permissionType,
    Map<String, dynamic>? assignedArea,
  }) async {
    try {
      final res = await _api.patch('/whiteboards/$whiteboardId/permissions', {
        if (targetUserId != null) 'target_user_id': targetUserId,
        if (targetRole != null) 'target_role': targetRole,
        'permission_type': permissionType,
        if (assignedArea != null) 'assigned_area': assignedArea,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('[WhiteboardApiService] setPermission error: $e');
      return false;
    }
  }

  Future<WhiteboardShareItem?> shareWhiteboard(
    String whiteboardId, {
    required String shareType,
    required String targetLabel,
    String accessLevel = 'VIEW',
    String? expiresAt,
  }) async {
    try {
      final res = await _api.post('/whiteboards/$whiteboardId/share', {
        'share_type': shareType,
        'target_label': targetLabel,
        'access_level': accessLevel,
        if (expiresAt != null) 'expires_at': expiresAt,
      });
      if (res['data'] is Map<String, dynamic>) {
        return WhiteboardShareItem.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] shareWhiteboard error: $e');
    }
    return null;
  }

  Future<List<WhiteboardShareItem>> listShares(String whiteboardId) async {
    try {
      final res = await _api.get('/whiteboards/$whiteboardId/shares', useCache: false);
      final list = res['data'] as List? ?? [];
      return list.whereType<Map<String, dynamic>>().map(WhiteboardShareItem.fromJson).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> revokeShare(String whiteboardId, String shareId) async {
    try {
      final res = await _api.delete('/whiteboards/$whiteboardId/shares/$shareId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> uploadAsset({
    required String whiteboardId,
    String? pageId,
    required String filename,
    required Uint8List bytes,
  }) async {
    try {
      final res = await _api.multipartPostBytes(
        '/whiteboards/$whiteboardId/assets',
        bytes,
        filename,
        'file',
        fields: {if (pageId != null) 'page_id': pageId},
      );
      if (res['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(res['data']);
      }
    } catch (e) {
      debugPrint('[WhiteboardApiService] uploadAsset error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> exportWhiteboard({
    required String whiteboardId,
    required String format,
    required String scope,
    String? pageId,
    List<String>? pageIds,
    String orientation = 'landscape',
  }) async {
    try {
      final res = await _api.post('/whiteboards/$whiteboardId/export', {
        'format': format,
        'scope': scope,
        if (pageId != null) 'page_id': pageId,
        if (pageIds != null) 'page_ids': pageIds,
        'orientation': orientation,
      });
      return res['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[WhiteboardApiService] exportWhiteboard error: $e');
      return null;
    }
  }
}
