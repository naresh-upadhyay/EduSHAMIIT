// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, undefined_function, undefined_method, undefined_identifier

import 'dart:async';
import 'dart:js';
import 'dart:html' as html;
import 'sse_client_stub.dart';

class WebSseClient implements SseClient {
  void _ensureJsFunction() {
    try {
      if (!context.hasProperty('shamiFetchStream')) {
        final script = html.ScriptElement()
          ..text = """
window.shamiFetchStream = async function(url, headers, body, onChunk, onDone, onError) {
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(body)
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error('HTTP ' + response.status + ': ' + text);
    }
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const chunk = decoder.decode(value, { stream: true });
      buffer += chunk;
      let lines = buffer.split('\\n');
      buffer = lines.pop();
      for (const line of lines) {
        onChunk(line);
      }
    }
    if (buffer.length > 0) {
      onChunk(buffer);
    }
    onDone();
  } catch (e) {
    onError(e.message || e.toString());
  }
}
          """;
        html.document.head?.append(script);
      }
    } catch (e) {
      // Silently catch injection errors
    }
  }

  @override
  Future<void> sendRequest({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required void Function(String chunk) onChunk,
    required void Function() onDone,
    required void Function(String error) onError,
  }) async {
    _ensureJsFunction();
    try {
      context.callMethod('shamiFetchStream', [
        uri.toString(),
        JsObject.jsify(headers),
        JsObject.jsify(body),
        allowInterop((String chunk) {
          onChunk(chunk);
        }),
        allowInterop(() {
          onDone();
        }),
        allowInterop((String err) {
          onError(err);
        }),
      ]);
    } catch (e) {
      onError(e.toString());
    }
  }
}

SseClient getSseClient() => WebSseClient();


