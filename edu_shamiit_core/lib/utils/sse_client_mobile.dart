import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sse_client_stub.dart';

class MobileSseClient implements SseClient {
  @override
  Future<void> sendRequest({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required void Function(String chunk) onChunk,
    required void Function() onDone,
    required void Function(String error) onError,
  }) async {
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = jsonEncode(body);

      final streamed = await request.send().timeout(
        const Duration(seconds: 90),
      );

      await for (final chunk in streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        onChunk(chunk);
      }
      onDone();
    } catch (e) {
      onError(e.toString());
    }
  }
}

SseClient getSseClient() => MobileSseClient();
