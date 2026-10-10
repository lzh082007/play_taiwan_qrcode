class ApiConfig {
  ApiConfig._();

  /// 後端 API 的 Base URL，Swagger 文件也在這個網址底下。
  ///
  /// 要改連本機或區網的後端時，執行時加上
  /// `--dart-define=API_BASE_URL=http://<電腦 IP>:5501` 即可，不用改程式。
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://backend.angelalala.com');
}
