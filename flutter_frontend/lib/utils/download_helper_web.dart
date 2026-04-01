import 'dart:html' as html;
import 'download_helper_stub.dart';

class WebDownloadHelper implements DownloadHelper {
  @override
  Future<void> downloadBytes(List<int> bytes, String fileName, {String? mimeType}) async {
    final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

DownloadHelper getDownloadHelper() => WebDownloadHelper();
