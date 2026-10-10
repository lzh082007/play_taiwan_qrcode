import '../models/qr_code_scan_result.dart';
import '../services/api_client.dart';

export '../services/api_client.dart' show ApiException, ApiConnectionException, ApiResponseFormatException, ApiFailure;

/// 後端的 QR Code 優惠券 API（Swagger 文件在 ApiConfig.baseUrl 底下）：
/// 商家綁定 QR Code、使用者掃描 QR Code、核銷優惠券。
///
/// 後端只把 `qr_uid` 當成一個字串，App 產生的 QR 代碼跟 NFC 貼紙序號都走這幾支 API。
class CouponRepository {
  CouponRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// 商家把 [qrUid] 綁到自己店家的優惠券（功能一），需要商家帳號登入。
  ///
  /// 失敗時丟出 [ApiFailure]：`isConflict`（HTTP 409）代表這個代碼已經
  /// 綁定過優惠券了；`isNotFound`（HTTP 404）代表找不到這張優惠券，
  /// 或這張優惠券不屬於目前登入的店家。
  Future<void> bindQrCode({required String qrUid, required int couponId}) async {
    await _apiClient.post('/api/merchant/qrcode/bind', body: {'qr_uid': qrUid, 'coupon_id': couponId});
  }

  /// 使用者掃描 QR Code（功能二）：一次拿到商家/景點資訊 + 優惠券資訊。
  ///
  /// 以遊客帳號登入、且 [asGuest] 為 false 時，後端會順便幫這個帳號領取
  /// 這張優惠券；[asGuest] 為 true 時不帶 Token，只查看內容。
  ///
  /// 失敗時丟出 [ApiFailure]；`isNotFound`（HTTP 404）代表這個代碼
  /// 還沒有綁定任何優惠券。
  Future<QrCodeScanResult> scanQrCode(String qrUid, {bool asGuest = false}) async {
    final result = await _apiClient.get('/api/qrcode/scan/${Uri.encodeComponent(qrUid)}', withAuth: !asGuest);
    if (result == null) {
      throw const ApiResponseFormatException('伺服器回應成功，但缺少 Result 內容。');
    }
    return QrCodeScanResult.fromJson(result);
  }

  /// 核銷目前登入帳號領取過的優惠券（功能三），需要登入。
  ///
  /// 失敗時丟出 [ApiFailure]；`isConflict`（HTTP 409）代表這張優惠券
  /// 尚未領取、或已經核銷過了。
  Future<void> redeemCoupon(int couponId) async {
    await _apiClient.post('/api/coupons/$couponId/redeem');
  }
}
