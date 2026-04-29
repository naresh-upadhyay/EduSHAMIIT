import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// Provider for API service
final apiServiceProvider = Provider<ApiService>((ref) {
  // Watch authentication state. This ensures that any provider watching 
  // apiServiceProvider is recreated when the user logs in or out.
  ref.watch(authProvider.select((s) => s.isAuthenticated));
  return ApiService();
});