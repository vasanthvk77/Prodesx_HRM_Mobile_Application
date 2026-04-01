abstract class DownloadHelper {
  Future<void> downloadBytes(List<int> bytes, String fileName, {String? mimeType});
}

DownloadHelper getDownloadHelper() => throw UnsupportedError('Cannot create a download helper');
