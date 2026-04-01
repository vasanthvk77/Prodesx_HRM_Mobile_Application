import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'download_helper_stub.dart';

class IoDownloadHelper implements DownloadHelper {
  @override
  Future<void> downloadBytes(List<int> bytes, String fileName, {String? mimeType}) async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
    
    final fullPath = '${directory!.path}/$fileName';
    final file = File(fullPath);
    await file.writeAsBytes(bytes);
    // Note: To open the file, use url_launcher or open_file if available.
  }
}

DownloadHelper getDownloadHelper() => IoDownloadHelper();
