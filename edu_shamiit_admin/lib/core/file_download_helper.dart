import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

void downloadFile(String content, String fileName) {
  downloadFileImpl(content, fileName);
}

void downloadBytes(List<int> bytes, String fileName, {String mimeType = 'application/pdf'}) {
  downloadBytesImpl(bytes, fileName, mimeType: mimeType);
}

