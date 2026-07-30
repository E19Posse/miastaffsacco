import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

class PdfDownloadService {
  static final _store = StorageService();

  /// Download a PDF from [path] (e.g. '/pdf/member-summary') and open it.
  /// Shows a snackbar on success or failure via [context].
  static Future<void> download(
    BuildContext context, {
    required String path,
    required String filename,
  }) async {
    final token = await _store.getToken();
    if (token == null) {
      _snack(context, 'Session expired. Please log in again.', error: true);
      return;
    }

    final url = ApiConstants.baseUrl.replaceAll(RegExp(r'api/$'), '') +
        'api' + path;

    try {
      final tempDir  = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$filename';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        onReceiveProgress: (received, total) {},
      );

      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done) {
        _snack(context, 'Could not open PDF. Check if a PDF viewer is installed.', error: true);
      }
    } on DioException catch (e) {
      _snack(context, 'Download failed: ${e.response?.statusCode ?? e.message}', error: true);
    } catch (e) {
      _snack(context, 'Download failed: $e', error: true);
    }
  }

  static void _snack(BuildContext context, String msg, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }
}
