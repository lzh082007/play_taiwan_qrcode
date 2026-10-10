import '../config/auth_session.dart';
import '../models/login_info.dart';
import '../services/api_client.dart';

export '../services/api_client.dart' show ApiException, ApiConnectionException, ApiResponseFormatException, ApiFailure;

/// 帳號登入（`POST /api/Auth/Login`），遊客、商家共用同一支 API。
class AuthRepository {
  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// 用帳號名稱（或信箱）與密碼登入，成功後存進 [AuthSession]。
  ///
  /// 帳號或密碼錯誤時丟出 [ApiFailure]，`message` 是後端給的錯誤說明。
  Future<LoginInfo> login({required String account, required String password}) async {
    final result = await _apiClient.post(
      '/api/Auth/Login',
      body: {'auth_name': account, 'auth_pswd': password},
      withAuth: false,
    );
    if (result == null) {
      throw const ApiResponseFormatException('伺服器回應成功，但缺少 Result 內容。');
    }
    final info = LoginInfo.fromJson(result);
    AuthSession.signIn(info);
    return info;
  }
}
