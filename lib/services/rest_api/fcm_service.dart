import 'package:dio/dio.dart';
import 'package:webview_base/config/http_config.dart';

class FcmService {
  Future<Response> save(params) {
    return AppHttp.post(params, 'firebase/create-token');
  }

  Future<Response> delete(String token) {
    return AppHttp.delete('firebase/delete-token/$token');
  }
}
