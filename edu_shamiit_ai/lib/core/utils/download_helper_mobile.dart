import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'download_helper_stub.dart';

class MobileDownloadHelper implements DownloadHelper {
  @override
  Future<void> downloadFile(String url, String filename) async {
    var downloadUrl = url;
    if (url.contains('/chat/image-proxy')) {
      downloadUrl = '$url&filename=$filename';
    }
    try {
      final response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) {
            dir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        }
        
        if (dir != null) {
          final filePath = '${dir.path}/$filename';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          return;
        }
      }
    } catch (_) {
      // Silently fall back to browser launch
    }

    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch download URL: $downloadUrl';
    }
  }
}

DownloadHelper getDownloadHelper() => MobileDownloadHelper();
