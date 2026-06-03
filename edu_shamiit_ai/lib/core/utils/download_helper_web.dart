// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'download_helper_stub.dart';

class WebDownloadHelper implements DownloadHelper {
  @override
  Future<void> downloadFile(String url, String filename) async {
    var downloadUrl = url;
    if (url.contains('/chat/image-proxy')) {
      downloadUrl = '$url&filename=$filename';
    }

    try {
      final xhr = html.HttpRequest();
      xhr.open('GET', downloadUrl);
      xhr.responseType = 'blob';

      final completer = Completer<void>();
      
      xhr.onLoad.listen((event) {
        if (xhr.status == 200) {
          final blob = xhr.response as html.Blob;
          final blobUrl = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: blobUrl)
            ..setAttribute("download", filename)
            ..style.display = 'none';
          html.document.body?.append(anchor);
          anchor.click();
          anchor.remove();
          html.Url.revokeObjectUrl(blobUrl);
          completer.complete();
        } else {
          completer.completeError(
              'Server returned status code ${xhr.status}');
        }
      });

      xhr.onError.listen((event) {
        completer.completeError('Network error occurred during download.');
      });

      xhr.send();
      await completer.future;
    } catch (e) {
      // Fallback: trigger simple anchor click in a new tab
      final anchor = html.AnchorElement(href: downloadUrl)
        ..setAttribute("download", filename)
        ..target = '_blank'
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      
      rethrow;
    }
  }

  @override
  Future<void> downloadBytes(List<int> bytes, String filename) async {
    try {
      final blob = html.Blob([bytes], 'application/octet-stream');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: blobUrl)
        ..setAttribute("download", filename)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(blobUrl);
    } catch (e) {
      final base64String = base64Encode(bytes);
      final dataUrl = 'data:application/octet-stream;base64,$base64String';
      final anchor = html.AnchorElement(href: dataUrl)
        ..setAttribute("download", filename)
        ..target = '_blank'
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    }
  }
}

DownloadHelper getDownloadHelper() => WebDownloadHelper();


