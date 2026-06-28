import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache_service.dart';

/// Provider for cache service
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});