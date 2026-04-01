import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_io.dart';

class FileDownloadUtils {
  static Future<void> download({
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final helper = getDownloadHelper();
    await helper.downloadBytes(bytes, fileName, mimeType: mimeType);
  }
}
