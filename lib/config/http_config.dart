import 'package:dio/dio.dart';

import 'env_config.dart';

class AppHttp {
  static Map<String, String> header = {
    'Content-type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<Response> post(dynamic params, String apiName) async {
    final env = EnvConfig.instance;
    final dio = Dio();
    final response = await dio.post(env.baseUrl + apiName, data: params);
    return response;
  }

  static Future<Response> delete(
    String apiName, {
    dynamic params,
  }) async {
    final env = EnvConfig.instance;
    final dio = Dio();
    final response = await dio.delete(env.baseUrl + apiName, data: params);
    return response;
  }
}
