import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../services/api_service.dart';
import '../utils/download_helper.dart';
import 'api_provider.dart';

// ============================================================================
// STATE
// ============================================================================

class DocumentsState {
  final List<DocumentModel> documents;
  final DocumentModel? selectedDocument;
  final List<FolderModel> folders;
  final List<FolderModel> allFoldersFlat;
  final String? activeFolderId;
  final String activeTab; // 'all', 'my_documents', 'shared_with_me', 'recent', 'starred', 'trash'
  final DocumentStatsModel stats;
  final String selectedFileType;
  final String selectedDepartment;
  final String selectedOwnerId;
  final List<Map<String, dynamic>> schoolUsers;
  final String searchQuery;
  final String sortBy;
  final String sortOrder;
  final bool isGridView;
  final int currentPage;
  final int pageSize;
  final int totalPages;
  final int totalRecords;
  final Set<String> selectedDocumentIds;

  final bool isLoading;
  final bool isFoldersLoading;
  final bool isStatsLoading;
  final bool isUploading;
  final String? error;
  final String? successMessage;
  final Map<String, int> categoryCounts;

  final List<DocumentVersionModel> versions;
  final List<DocumentShareModel> shares;
  final List<DocumentActivityModel> activities;
  final List<DocumentRequestModel> requests;

  const DocumentsState({
    this.documents = const [],
    this.selectedDocument,
    this.folders = const [],
    this.allFoldersFlat = const [],
    this.activeFolderId,
    this.activeTab = 'all',
    this.stats = const DocumentStatsModel(),
    this.selectedFileType = 'All',
    this.selectedDepartment = 'All',
    this.selectedOwnerId = 'All',
    this.schoolUsers = const [],
    this.searchQuery = '',
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
    this.isGridView = true,
    this.currentPage = 1,
    this.pageSize = 12,
    this.totalPages = 1,
    this.totalRecords = 0,
    this.selectedDocumentIds = const {},
    this.isLoading = false,
    this.isFoldersLoading = false,
    this.isStatsLoading = false,
    this.isUploading = false,
    this.error,
    this.successMessage,
    this.categoryCounts = const {},
    this.versions = const [],
    this.shares = const [],
    this.activities = const [],
    this.requests = const [],
  });

  DocumentsState copyWith({
    List<DocumentModel>? documents,
    DocumentModel? selectedDocument,
    bool clearSelectedDocument = false,
    List<FolderModel>? folders,
    List<FolderModel>? allFoldersFlat,
    String? activeFolderId,
    bool clearActiveFolder = false,
    String? activeTab,
    DocumentStatsModel? stats,
    String? selectedFileType,
    String? selectedDepartment,
    String? selectedOwnerId,
    List<Map<String, dynamic>>? schoolUsers,
    String? searchQuery,
    String? sortBy,
    String? sortOrder,
    bool? isGridView,
    int? currentPage,
    int? pageSize,
    int? totalPages,
    int? totalRecords,
    Set<String>? selectedDocumentIds,
    bool? isLoading,
    bool? isFoldersLoading,
    bool? isStatsLoading,
    bool? isUploading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    Map<String, int>? categoryCounts,
    List<DocumentVersionModel>? versions,
    List<DocumentShareModel>? shares,
    List<DocumentActivityModel>? activities,
    List<DocumentRequestModel>? requests,
  }) {
    return DocumentsState(
      documents: documents ?? this.documents,
      selectedDocument: clearSelectedDocument ? null : (selectedDocument ?? this.selectedDocument),
      folders: folders ?? this.folders,
      allFoldersFlat: allFoldersFlat ?? this.allFoldersFlat,
      activeFolderId: clearActiveFolder ? null : (activeFolderId ?? this.activeFolderId),
      activeTab: activeTab ?? this.activeTab,
      stats: stats ?? this.stats,
      selectedFileType: selectedFileType ?? this.selectedFileType,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      selectedOwnerId: selectedOwnerId ?? this.selectedOwnerId,
      schoolUsers: schoolUsers ?? this.schoolUsers,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      isGridView: isGridView ?? this.isGridView,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      totalRecords: totalRecords ?? this.totalRecords,
      selectedDocumentIds: selectedDocumentIds ?? this.selectedDocumentIds,
      isLoading: isLoading ?? this.isLoading,
      isFoldersLoading: isFoldersLoading ?? this.isFoldersLoading,
      isStatsLoading: isStatsLoading ?? this.isStatsLoading,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      categoryCounts: categoryCounts ?? this.categoryCounts,
      versions: versions ?? this.versions,
      shares: shares ?? this.shares,
      activities: activities ?? this.activities,
      requests: requests ?? this.requests,
    );
  }

  int countFor(DocumentCategory cat) => categoryCounts[cat.value] ?? 0;
}

// ============================================================================
// NOTIFIER
// ============================================================================

class DocumentsNotifier extends StateNotifier<DocumentsState> {
  final ApiService _api;

  DocumentsNotifier(this._api) : super(const DocumentsState());

  /// Initial full synchronization.
  Future<void> init() async {
    await Future.wait([
      loadStats(),
      loadFolders(),
      loadDocuments(page: 1),
      loadUsers(),
      loadRequests(),
    ]);
  }

  /// Load KPI statistics from `/documents/stats`.
  Future<void> loadStats() async {
    state = state.copyWith(isStatsLoading: true);
    try {
      final res = await _api.get('/documents/stats', useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final stats = DocumentStatsModel.fromJson(data);
      state = state.copyWith(isStatsLoading: false, stats: stats);
    } catch (_) {
      state = state.copyWith(isStatsLoading: false);
    }
  }

  /// Load school users for filtering and sharing.
  Future<void> loadUsers() async {
    try {
      final users = await searchUsers('');
      state = state.copyWith(schoolUsers: users);
    } catch (_) {}
  }

  /// Load folder hierarchy from `/documents/folders` with active tab context.
  Future<void> loadFolders() async {
    state = state.copyWith(isFoldersLoading: true);
    try {
      final res = await _api.get('/documents/folders', query: {'tab': state.activeTab}, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final rawRoots = data['folders'] as List<dynamic>? ?? [];
      final rawFlat = data['all_folders_flat'] as List<dynamic>? ?? [];

      final roots = rawRoots.map((f) => FolderModel.fromJson(f as Map<String, dynamic>)).toList();
      final flat = rawFlat.map((f) => FolderModel.fromJson(f as Map<String, dynamic>)).toList();

      state = state.copyWith(
        isFoldersLoading: false,
        folders: roots,
        allFoldersFlat: flat,
      );
    } catch (e) {
      state = state.copyWith(isFoldersLoading: false);
    }
  }

  /// Load documents with active tab, folder, file type, owner, search, sorting, and pagination.
  Future<void> loadDocuments({
    int? page,
    int? pageSize,
    DocumentCategory? category,
    String? sortBy,
    String? sortOrder,
  }) async {
    final targetPage = page ?? state.currentPage;
    final targetPageSize = pageSize ?? state.pageSize;
    final targetSortBy = sortBy ?? state.sortBy;
    final targetSortOrder = sortOrder ?? state.sortOrder;

    state = state.copyWith(
      isLoading: true,
      currentPage: targetPage,
      pageSize: targetPageSize,
      sortBy: targetSortBy,
      sortOrder: targetSortOrder,
      clearError: true,
    );

    try {
      final query = <String, dynamic>{
        'tab': state.activeTab,
        'page': targetPage,
        'page_size': targetPageSize,
        'sort_by': targetSortBy,
        'sort_order': targetSortOrder,
      };

      if (state.activeFolderId != null) {
        query['folder_id'] = state.activeFolderId!;
      }
      if (category != null) {
        query['category'] = category.value;
      }
      if (state.selectedFileType != 'All') {
        query['file_type'] = state.selectedFileType;
      }
      if (state.selectedDepartment != 'All') {
        query['department'] = state.selectedDepartment;
      }
      if (state.selectedOwnerId != 'All' && state.selectedOwnerId.isNotEmpty) {
        query['owner_id'] = state.selectedOwnerId;
      }
      if (state.searchQuery.trim().isNotEmpty) {
        query['search'] = state.searchQuery.trim();
      }

      final res = await _api.get('/documents', query: query, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};

      final rawItems = (data['items'] ?? data['documents']) as List<dynamic>? ?? [];
      final docs = rawItems.map((d) => DocumentModel.fromJson(d as Map<String, dynamic>)).toList();

      final total = (data['total'] as num?)?.toInt() ?? docs.length;
      final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;

      final rawCounts = data['category_counts'] as Map<String, dynamic>? ?? {};
      final counts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

      // Preserve or set selectedDocument
      DocumentModel? newSelected = state.selectedDocument;
      if (docs.isNotEmpty) {
        if (newSelected == null) {
          newSelected = docs.first;
        } else {
          final matched = docs.where((d) => d.id == newSelected?.id);
          newSelected = matched.isNotEmpty ? matched.first : docs.first;
        }
      } else {
        newSelected = null;
      }

      state = state.copyWith(
        isLoading: false,
        documents: docs,
        totalRecords: total,
        totalPages: totalPages,
        categoryCounts: counts,
        selectedDocument: newSelected,
      );

      if (newSelected != null) {
        loadDocumentDetails(newSelected.id);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Switch tab (All, My Documents, Shared with Me, Recent, Starred, Trash).
  Future<void> selectTab(String tab) async {
    if (tab == state.activeTab) return;
    state = state.copyWith(activeTab: tab, clearActiveFolder: true, currentPage: 1, selectedDocumentIds: {});
    await Future.wait([
      loadFolders(),
      loadDocuments(page: 1),
    ]);
  }

  /// Select folder in tree.
  Future<void> selectFolder(String? folderId) async {
    if (folderId == state.activeFolderId) return;
    state = state.copyWith(
      activeFolderId: folderId,
      clearActiveFolder: folderId == null,
      currentPage: 1,
    );
    await loadDocuments(page: 1);
  }

  /// Select document for Right Preview panel.
  void selectDocument(DocumentModel? doc) {
    state = state.copyWith(
      selectedDocument: doc,
      clearSelectedDocument: doc == null,
    );
    if (doc != null) {
      loadDocumentDetails(doc.id);
    }
  }

  /// Load extra details for selected document (versions, shares, activities).
  Future<void> loadDocumentDetails(String docId) async {
    try {
      final res = await _api.get('/documents/$docId', useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final docData = data['document'] as Map<String, dynamic>? ?? {};

      final rawVersions = docData['versions'] as List<dynamic>? ?? [];
      final rawShares = docData['shares'] as List<dynamic>? ?? [];
      final rawActivities = docData['activities'] as List<dynamic>? ?? [];

      state = state.copyWith(
        versions: rawVersions.map((v) => DocumentVersionModel.fromJson(v as Map<String, dynamic>)).toList(),
        shares: rawShares.map((s) => DocumentShareModel.fromJson(s as Map<String, dynamic>)).toList(),
        activities: rawActivities.map((a) => DocumentActivityModel.fromJson(a as Map<String, dynamic>)).toList(),
      );
    } catch (_) {}
  }

  /// Change file type filter.
  Future<void> setFileTypeFilter(String type) async {
    if (type == state.selectedFileType) return;
    state = state.copyWith(selectedFileType: type, currentPage: 1);
    await loadDocuments(page: 1);
  }

  /// Change department filter.
  Future<void> setDepartmentFilter(String dept) async {
    if (dept == state.selectedDepartment) return;
    state = state.copyWith(selectedDepartment: dept, currentPage: 1);
    await loadDocuments(page: 1);
  }

  /// Change owner filter.
  Future<void> setOwnerFilter(String? ownerId) async {
    if (ownerId == state.selectedOwnerId) return;
    state = state.copyWith(selectedOwnerId: ownerId, currentPage: 1);
    await loadDocuments(page: 1);
  }

  /// Set search query.
  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query, currentPage: 1);
    await loadDocuments(page: 1);
  }

  /// Change sorting field and order.
  Future<void> setSort(String field, {String? order}) async {
    final nextOrder = order ?? (state.sortBy == field && state.sortOrder == 'asc' ? 'desc' : 'asc');
    state = state.copyWith(sortBy: field, sortOrder: nextOrder, currentPage: 1);
    await loadDocuments(page: 1, sortBy: field, sortOrder: nextOrder);
  }

  /// Set page size and reload page 1.
  Future<void> setPageSize(int pageSize) async {
    state = state.copyWith(pageSize: pageSize, currentPage: 1);
    await loadDocuments(page: 1, pageSize: pageSize);
  }

  /// Toggle between Grid View and Table View.
  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  /// Toggle item selection for bulk operations.
  void toggleDocumentSelection(String docId) {
    final next = Set<String>.from(state.selectedDocumentIds);
    if (next.contains(docId)) {
      next.remove(docId);
    } else {
      next.add(docId);
    }
    state = state.copyWith(selectedDocumentIds: next);
  }

  /// Select all visible documents.
  void selectAllVisible() {
    final next = state.documents.map((d) => d.id).toSet();
    state = state.copyWith(selectedDocumentIds: next);
  }

  /// Toggle select all or clear selection.
  void toggleSelectAll() {
    if (state.selectedDocumentIds.length == state.documents.length && state.documents.isNotEmpty) {
      clearSelection();
    } else {
      selectAllVisible();
    }
  }

  /// Clear selection.
  void clearSelection() {
    state = state.copyWith(selectedDocumentIds: {});
  }

  /// Create new folder.
  Future<bool> createFolder({
    required String name,
    String? description,
    String? parentId,
    String category = 'General',
    String color = '#2563EB',
    String icon = 'folder',
  }) async {
    try {
      await _api.post('/documents/folders', {
        'name': name,
        'description': description,
        'parent_id': parentId,
        'category': category,
        'color': color,
        'icon': icon,
      });
      state = state.copyWith(successMessage: 'Folder "$name" created successfully');
      await loadFolders();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Delete folder and reassign child documents to parent.
  Future<bool> deleteFolder(String folderId) async {
    try {
      await _api.delete('/documents/folders/$folderId');
      state = state.copyWith(
        clearActiveFolder: state.activeFolderId == folderId,
        successMessage: 'Folder deleted successfully',
      );
      await Future.wait([loadFolders(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete folder: $e');
      return false;
    }
  }

  /// Upload personal or institutional file.
  Future<bool> uploadDocument({
    required List<int> bytes,
    required String filename,
    required String title,
    String description = '',
    String category = 'my_uploads',
    String? folderId,
    String department = 'All',
    String tags = '',
    bool approvalRequired = false,
    String? expiryDate,
  }) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      final fields = <String, String>{
        'title': title,
        'description': description,
        'category': category,
        'department': department,
        'tags': tags,
        'approval_required': approvalRequired ? 'true' : 'false',
      };
      if (folderId != null) fields['folder_id'] = folderId;
      if (expiryDate != null) fields['expiry_date'] = expiryDate;

      await _api.multipartPostBytes(
        '/documents/upload',
        bytes,
        filename,
        'file',
        fields: fields,
      );

      state = state.copyWith(
        isUploading: false,
        successMessage: 'Document uploaded successfully!',
      );
      await Future.wait([loadStats(), loadFolders(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      return false;
    }
  }

  /// Save an AI-generated document from chat.
  Future<bool> saveAiDocument({
    required String title,
    required String content,
    String? sessionId,
    String description = '',
  }) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      await _api.post('/documents/save-ai', {
        'title': title,
        'content': content,
        if (sessionId != null) 'session_id': sessionId,
        'description': description,
      });
      state = state.copyWith(
        isUploading: false,
        successMessage: 'Document saved to repository!',
      );
      await Future.wait([loadStats(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      return false;
    }
  }

  /// Delete or move to trash.
  Future<bool> deleteDocument(String docId, {bool permanent = false}) async {
    try {
      final endpoint = '/documents/$docId${permanent ? "?permanent=true" : "" }';
      await _api.delete(endpoint);
      state = state.copyWith(
        documents: state.documents.where((d) => d.id != docId).toList(),
        successMessage: permanent ? 'Document permanently deleted' : 'Moved to Trash',
      );
      await Future.wait([loadStats(), loadFolders(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Restore from trash.
  Future<bool> restoreDocument(String docId, {String? targetFolderId}) async {
    try {
      final endpoint = '/documents/$docId/restore${targetFolderId != null ? "?target_folder_id=$targetFolderId" : ""}';
      await _api.post(endpoint, {});
      state = state.copyWith(successMessage: 'Document restored from Trash');
      await Future.wait([loadStats(), loadFolders(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Empty trash completely.
  Future<bool> emptyTrash() async {
    try {
      await _api.post('/documents/empty-trash', {});
      state = state.copyWith(successMessage: 'Trash emptied successfully');
      await Future.wait([loadStats(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Bulk restore soft-deleted documents from Trash.
  Future<bool> bulkRestore() async {
    if (state.selectedDocumentIds.isEmpty) return false;
    try {
      await _api.post('/documents/bulk/restore', {
        'document_ids': state.selectedDocumentIds.toList(),
      });
      state = state.copyWith(
        selectedDocumentIds: {},
        successMessage: 'Restored selected documents from Trash',
      );
      await Future.wait([loadStats(), loadFolders(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Bulk move documents.
  Future<bool> bulkMove(String? targetFolderId) async {
    if (state.selectedDocumentIds.isEmpty) return false;
    try {
      await _api.post('/documents/bulk/move', {
        'document_ids': state.selectedDocumentIds.toList(),
        'target_folder_id': targetFolderId,
      });
      state = state.copyWith(
        selectedDocumentIds: {},
        successMessage: 'Moved selected documents',
      );
      await Future.wait([loadFolders(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Bulk delete documents.
  Future<bool> bulkDelete({bool permanent = false}) async {
    if (state.selectedDocumentIds.isEmpty) return false;
    try {
      final endpoint = '/documents/bulk/delete${permanent ? "?permanent=true" : ""}';
      await _api.post(endpoint, {
        'document_ids': state.selectedDocumentIds.toList(),
      });
      state = state.copyWith(
        selectedDocumentIds: {},
        successMessage: permanent ? 'Permanently deleted selected documents' : 'Moved selected documents to Trash',
      );
      await Future.wait([loadStats(), loadFolders(), loadDocuments()]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Bulk star/unstar.
  Future<bool> bulkStar({bool star = true}) async {
    if (state.selectedDocumentIds.isEmpty) return false;
    try {
      final endpoint = '/documents/bulk/star?star=$star';
      await _api.post(endpoint, {
        'document_ids': state.selectedDocumentIds.toList(),
      });
      state = state.copyWith(
        selectedDocumentIds: {},
        successMessage: star ? 'Starred selected documents' : 'Unstarred selected documents',
      );
      await loadDocuments();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Download selected documents in a compressed ZIP archive.
  Future<void> downloadBulkZip() async {
    if (state.selectedDocumentIds.isEmpty) return;
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final bytes = await _api.postBytes('/documents/bulk/download-zip', {
        'document_ids': state.selectedDocumentIds.toList(),
      });
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'EduSHAMIIT_Documents_$timestamp.zip';
      await getDownloadHelper().downloadBytes(bytes, filename);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Downloaded ${state.selectedDocumentIds.length} files as ZIP archive',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'ZIP download error: $e');
    }
  }

  /// Toggle star favorite.
  Future<void> toggleFavorite(String docId) async {
    try {
      final res = await _api.post('/documents/$docId/favorite', {});
      final isStarred = res['is_starred'] as bool? ?? false;

      final updated = state.documents.map((d) {
        if (d.id == docId) {
          return DocumentModel.fromJson({
            ...Map<String, dynamic>.from(d.toJsonMap()),
            'is_starred': isStarred,
          });
        }
        return d;
      }).toList();

      state = state.copyWith(
        documents: updated,
        successMessage: isStarred ? 'Added to Starred' : 'Removed from Starred',
      );
      if (state.activeTab == 'starred') {
        await loadDocuments();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Share document.
  Future<bool> shareDocument({
    required String docId,
    required String shareType,
    String? targetId,
    String? targetName,
    String permissionLevel = 'Viewer',
    bool allowDownload = true,
    bool allowPrint = true,
    String? expiryDate,
    String? message,
  }) async {
    try {
      await _api.post('/documents/$docId/share', {
        'share_type': shareType,
        'target_id': targetId,
        'target_name': targetName,
        'permission_level': permissionLevel,
        'allow_download': allowDownload,
        'allow_print': allowPrint,
        'expiry_date': expiryDate,
        'message': message,
      });
      state = state.copyWith(successMessage: 'Document shared with $targetName');
      await loadDocumentDetails(docId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Revoke document share.
  Future<bool> revokeShare(String shareId, String docId) async {
    try {
      await _api.delete('/documents/shares/$shareId');
      state = state.copyWith(successMessage: 'Share access revoked');
      await loadDocumentDetails(docId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Upload replacement version.
  Future<bool> uploadNewVersion({
    required String docId,
    required List<int> bytes,
    required String filename,
    String changeSummary = 'Updated version',
  }) async {
    try {
      await _api.multipartPostBytes(
        '/documents/$docId/versions',
        bytes,
        filename,
        'file',
        fields: {'change_summary': changeSummary},
      );
      state = state.copyWith(successMessage: 'New version uploaded successfully');
      await Future.wait([loadDocuments(), loadDocumentDetails(docId)]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Restore historical version.
  Future<bool> restoreVersion(String docId, String versionId) async {
    try {
      await _api.post('/documents/$docId/versions/$versionId/restore', {});
      state = state.copyWith(successMessage: 'Version restored as current document');
      await Future.wait([loadDocuments(), loadDocumentDetails(docId)]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Submit for approval.
  Future<bool> submitApproval(String docId, String comments) async {
    try {
      await _api.post('/documents/$docId/submit-approval', {'comments': comments});
      state = state.copyWith(successMessage: 'Submitted for approval');
      await Future.wait([loadStats(), loadDocuments(), loadDocumentDetails(docId)]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Approve document.
  Future<bool> approveDocument(String docId, String comments) async {
    try {
      await _api.post('/documents/$docId/approve', {'comments': comments});
      state = state.copyWith(successMessage: 'Document approved');
      await Future.wait([loadStats(), loadDocuments(), loadDocumentDetails(docId)]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Reject document.
  Future<bool> rejectDocument(String docId, String reason) async {
    try {
      await _api.post('/documents/$docId/reject', {'reason': reason});
      state = state.copyWith(successMessage: 'Document rejected with reason recorded');
      await Future.wait([loadStats(), loadDocuments(), loadDocumentDetails(docId)]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Review approval (approve or reject with comments).
  Future<bool> reviewApproval(String docId, {required String status, String? comments}) async {
    if (status.toLowerCase() == 'approved') {
      return approveDocument(docId, comments ?? 'Approved');
    } else {
      return rejectDocument(docId, comments ?? 'Rejected');
    }
  }

  /// Load all document requests.
  Future<void> loadRequests({String? status}) async {
    try {
      final endpoint = '/documents/requests${status != null && status != "All" ? "?status=$status" : ""}';
      final res = await _api.get(endpoint, useCache: false);
      final rawList = res['data']?['requests'] as List<dynamic>? ?? [];
      final reqs = rawList.map((r) => DocumentRequestModel.fromJson(r as Map<String, dynamic>)).toList();
      state = state.copyWith(requests: reqs);
    } catch (_) {}
  }

  /// Submit document request.
  Future<bool> createDocumentRequest({
    required String title,
    String? description,
    String category = 'General',
    String priority = 'Medium',
    String? requiredByDate,
  }) async {
    try {
      await _api.post('/documents/requests', {
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
        'required_by_date': requiredByDate,
      });
      state = state.copyWith(successMessage: 'Document request submitted successfully');
      await loadRequests();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Fulfill a document request with an uploaded or chosen document.
  Future<bool> fulfillRequest(String requestId, {required String documentId, String? responseNotes}) async {
    try {
      final endpoint = '/documents/requests/$requestId/fulfill?document_id=$documentId${responseNotes != null ? "&notes=${Uri.encodeComponent(responseNotes)}" : ""}';
      await _api.post(endpoint, {});
      state = state.copyWith(successMessage: 'Request fulfilled successfully');
      await loadRequests();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update document request status.
  Future<bool> updateRequestStatus(String requestId, {required String status, String? responseNotes}) async {
    try {
      await _api.patch('/documents/requests/$requestId', {
        'status': status,
        'response_notes': responseNotes,
      });
      state = state.copyWith(successMessage: 'Request status updated to $status');
      await loadRequests();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Sync external module documents.
  Future<void> syncCrossModule() async {
    try {
      state = state.copyWith(isLoading: true);
      final res = await _api.post('/documents/sync-cross-module', {});
      final count = res['synced_count'] ?? 0;
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Synchronized cross-module documents ($count new files indexed)',
      );
      await Future.wait([loadStats(), loadFolders(), loadDocuments()]);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Sync failed: $e');
    }
  }

  /// Switch category tab for backward compatibility.
  Future<void> setCategory(DocumentCategory? category) async {
    await loadDocuments(category: category);
  }

  /// Search real application users for document sharing.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final res = await _api.get('/documents/users/search?q=${Uri.encodeComponent(query)}');
      final usersData = res['data']?['users'] as List<dynamic>? ?? [];
      return usersData.map((u) => Map<String, dynamic>.from(u as Map)).toList();
    } catch (e) {
      try {
        final res = await _api.get('/shared/users/search?q=${Uri.encodeComponent(query)}');
        final usersData = res['data']?['users'] as List<dynamic>? ?? [];
        return usersData.map((u) => Map<String, dynamic>.from(u as Map)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Get live collaborative editor URL for Word / Excel files.
  Future<Map<String, dynamic>?> getLiveEditorUrl(String docId, {String service = 'google'}) async {
    try {
      final res = await _api.get('/documents/$docId/live-editor?service=$service');
      return res['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

// Extension on DocumentModel for converting to JSON map for quick clone
extension DocumentModelJsonExt on DocumentModel {
  Map<String, dynamic> toJsonMap() => {
    'id': id,
    'school_id': schoolId,
    'owner_id': ownerId,
    'owner_name': ownerName,
    'owner_role': ownerRole,
    'owner_avatar': ownerAvatar,
    'title': title,
    'description': description,
    'category': categoryRaw,
    'file_url': fileUrl,
    'file_name': fileName,
    'file_size': fileSize,
    'mime_type': mimeType,
    'content': content,
    'storage_path': storagePath,
    'folder_id': folderId,
    'folder_name': folderName,
    'department': department,
    'tags': tags,
    'file_type': fileType,
    'access_type': accessType,
    'approval_status': approvalStatus,
    'version_number': versionNumber,
    'is_starred': isStarred,
    'is_archived': isArchived,
    'is_deleted': isDeleted,
    'deleted_at': deletedAt?.toIso8601String(),
    'expiry_date': expiryDate?.toIso8601String(),
    'download_count': downloadCount,
    'preview_count': previewCount,
    'versions_count': versionsCount,
    'shares_count': sharesCount,
    'source_chat_session_id': sourceChatSessionId,
    'shared_by_id': sharedById,
    'shared_by_name': sharedByName,
    'shared_by_role': sharedByRole,
    'current_user_permission': currentUserPermission,
    'allow_download': allowDownload,
    'created_at': createdAt.toIso8601String(),
    'updated_at': (updatedAt ?? createdAt).toIso8601String(),
  };
}

// ============================================================================
// PROVIDER
// ============================================================================

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, DocumentsState>((ref) {
  final notifier = DocumentsNotifier(ref.watch(apiServiceProvider));
  return notifier;
});
