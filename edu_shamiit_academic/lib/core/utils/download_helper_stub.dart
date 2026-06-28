abstract class DownloadHelper {
  Future<void> downloadFile(String url, String filename);
  Future<void> downloadBytes(List<int> bytes, String filename);
}

DownloadHelper getDownloadHelper() => throw UnsupportedError('Cannot create download helper without platform');

