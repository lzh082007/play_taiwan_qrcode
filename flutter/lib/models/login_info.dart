/// `POST /api/Auth/Login` 成功時回傳的帳號資訊。
class LoginInfo {
  const LoginInfo({
    required this.token,
    required this.auId,
    required this.authName,
    required this.authType,
    required this.storeId,
  });

  /// JWT，呼叫需要登入的 API 時放在 `Authorization: Bearer {token}`。
  final String token;
  final int auId;
  final String authName;

  /// 帳號類型：1 = 遊客、2 = 商家、3 = 管理員。
  final int authType;

  /// 商家帳號的店家代號（store.s_id），非商家帳號是 null。
  final int? storeId;

  bool get isTourist => authType == 1;
  bool get isMerchant => authType == 2;

  String get roleLabel => switch (authType) {
    1 => '遊客',
    2 => '商家',
    3 => '管理員',
    _ => '未知身分',
  };

  factory LoginInfo.fromJson(Map<String, dynamic> json) {
    return LoginInfo(
      token: json['token'] as String,
      auId: json['au_id'] as int,
      authName: json['auth_name'] as String? ?? '',
      authType: json['auth_type'] as int,
      storeId: json['store_id'] as int?,
    );
  }
}
