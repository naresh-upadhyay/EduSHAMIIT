import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';

/// Provider for the currently selected child's student ID.
/// When null, the first child from the children list is used.
final selectedChildProvider = StateProvider<String?>((ref) => null);

/// Provider that fetches the list of children linked to this parent.
final childrenProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return [];
  }

  final api = ApiService();
  final response = await api.get('/parent/children');

  if (response['success'] == true && response['data'] != null) {
    final children = response['data']['children'] as List<dynamic>? ?? [];
    final childrenList = children.cast<Map<String, dynamic>>();

    // Auto-select first child if none selected
    final selectedId = ref.read(selectedChildProvider);
    if (selectedId == null && childrenList.isNotEmpty) {
      ref.read(selectedChildProvider.notifier).state =
          childrenList.first['student_id'];
    }

    return childrenList;
  }

  return [];
});

/// Provider that fetches the parent dashboard data for the selected child.
final parentDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final response = await api.get(
    '/parent/dashboard',
    query: {'student_id': selectedChildId},
  );

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent attendance data.
final parentAttendanceProvider =
    FutureProvider.family<Map<String, dynamic>, String?>((ref, month) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final query = <String, dynamic>{'student_id': selectedChildId};
  if (month != null) query['month'] = month;

  final response = await api.get('/parent/attendance', query: query);

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent results data.
final parentResultsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final response = await api.get(
    '/parent/results',
    query: {'student_id': selectedChildId},
  );

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent fees data.
final parentFeesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final response = await api.get(
    '/parent/fees',
    query: {'student_id': selectedChildId},
  );

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent homework data.
final parentHomeworkProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final response = await api.get(
    '/parent/homework',
    query: {'student_id': selectedChildId},
  );

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent leave data.
final parentLeaveProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final response = await api.get(
    '/parent/leave',
    query: {'student_id': selectedChildId},
  );

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent transport data.
final parentTransportProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final response = await api.get(
    '/parent/transport',
    query: {'student_id': selectedChildId},
  );

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent achievements data.
final parentAchievementsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final response = await api.get(
    '/parent/achievements',
    query: {'student_id': selectedChildId},
  );

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent timetable data.
final parentTimetableProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, day) async {
  final authState = ref.watch(authProvider);
  final selectedChildId = ref.watch(selectedChildProvider);

  if (!authState.isAuthenticated || selectedChildId == null) {
    return {};
  }

  final api = ApiService();
  final response = await api.get(
    '/parent/timetable',
    query: {'student_id': selectedChildId, 'day': day},
  );

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent notifications.
final parentNotificationsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return {};
  }

  final api = ApiService();
  final response = await api.get('/parent/notifications');

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent messages.
final parentMessagesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return {};
  }

  final api = ApiService();
  final response = await api.get('/parent/messages');

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent profile.
final parentProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return {};
  }

  final api = ApiService();
  final response = await api.get('/parent/profile');

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent notices.
final parentNoticesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return {};
  }

  final api = ApiService();
  final response = await api.get('/parent/notices');

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});

/// Provider for parent events.
final parentEventsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return {};
  }

  final api = ApiService();
  final response = await api.get('/parent/events');

  if (response['success'] == true && response['data'] != null) {
    return response['data'] as Map<String, dynamic>;
  }

  return {};
});
