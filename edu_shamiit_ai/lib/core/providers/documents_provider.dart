import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/models/document_model.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/providers/api_provider.dart';

// ============================================================================
// STATE
// ============================================================================

class DocumentsState {
  final List<DocumentModel> documents;
  final bool isLoading;
  final bool isUploading;
  final String? error;
  final String? successMessage;
  final DocumentCategory? activeCategory;
  final Map<String, int> categoryCounts;

  const DocumentsState({
    this.documents = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.error,
    this.successMessage,
    this.activeCategory,
    this.categoryCounts = const {},
  });

  DocumentsState copyWith({
    List<DocumentModel>? documents,
    bool? isLoading,
    bool? isUploading,
    String? error,
    String? successMessage,
    DocumentCategory? activeCategory,
    Map<String, int>? categoryCounts,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return DocumentsState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      activeCategory: activeCategory ?? this.activeCategory,
      categoryCounts: categoryCounts ?? this.categoryCounts,
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

  /// Load documents, optionally filtered by category.
  Future<void> loadDocuments({DocumentCategory? category}) async {
    state = state.copyWith(
      isLoading: true,
      activeCategory: category,
      clearError: true,
    );
    try {
      final query = <String, dynamic>{};
      if (category != null) query['category'] = category.value;

      final response = await _api.get('/documents', query: query, useCache: false);
      final data = response['data'] as Map<String, dynamic>? ?? {};

      final rawDocs = data['documents'] as List<dynamic>? ?? [];
      final docs = rawDocs.map((d) => DocumentModel.fromJson(d as Map<String, dynamic>)).toList();

      final rawCounts = data['category_counts'] as Map<String, dynamic>? ?? {};
      final counts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

      state = state.copyWith(
        isLoading: false,
        documents: docs,
        categoryCounts: counts,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Save an AI-generated text document to the hub.
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
        successMessage: 'Document saved to your Documents Hub!',
      );
      // Reload to reflect updated counts
      await loadDocuments(category: state.activeCategory);
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      return false;
    }
  }

  /// Upload a personal file to the hub.
  Future<bool> uploadDocument({
    required List<int> bytes,
    required String filename,
    required String title,
    String description = '',
    DocumentCategory category = DocumentCategory.myUploads,
  }) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      await _api.multipartPostBytes(
        '/documents/upload',
        bytes,
        filename,
        'file',
        fields: {
          'title': title,
          'description': description,
          'category': category.value,
        },
      );
      state = state.copyWith(
        isUploading: false,
        successMessage: 'Document uploaded successfully!',
      );
      await loadDocuments(category: state.activeCategory);
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      return false;
    }
  }

  /// Delete a document (owner only).
  Future<bool> deleteDocument(String docId) async {
    try {
      await _api.delete('/documents/$docId');
      state = state.copyWith(
        documents: state.documents.where((d) => d.id != docId).toList(),
        successMessage: 'Document deleted.',
      );
      // Refresh counts
      await loadDocuments(category: state.activeCategory);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Switch the active category tab and reload.
  Future<void> setCategory(DocumentCategory? category) async {
    if (category == state.activeCategory && state.documents.isNotEmpty) return;
    await loadDocuments(category: category);
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, DocumentsState>((ref) {
  return DocumentsNotifier(ref.watch(apiServiceProvider));
});
