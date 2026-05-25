import 'dart:async';

abstract class SseClient {
  Future<void> sendRequest({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required void Function(String chunk) onChunk,
    required void Function() onDone,
    required void Function(String error) onError,
  });
}

SseClient getSseClient() => throw UnsupportedError('Cannot create SSE client without platform');
