import 'package:flutter/foundation.dart';

import '../models/login_info.dart';

/// 目前的登入狀態，只存在記憶體裡，App 關掉後要重新登入。
///
/// 畫面可以用 `ValueListenableBuilder` 監聽 [current]：登入、登出、
/// 或呼叫 API 時發現 Token 已過期被清掉，畫面都會跟著更新。
class AuthSession {
  AuthSession._();

  static final ValueNotifier<LoginInfo?> current = ValueNotifier(null);

  static LoginInfo? get info => current.value;

  static String? get token => current.value?.token;

  static void signIn(LoginInfo info) => current.value = info;

  static void signOut() => current.value = null;
}
