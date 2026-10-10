import 'package:flutter/material.dart';

import '../config/auth_session.dart';
import '../models/qr_code_scan_result.dart';
import '../repositories/coupon_repository.dart';
import '../services/nfc_service.dart';
import '../services/qr_service.dart';
import '../widgets/coupon_card.dart';
import '../widgets/merchant_place_card.dart';

enum _ScanMethod { nfc, qr }

sealed class ScanResultState {
  const ScanResultState();
}

class ScanIdle extends ScanResultState {
  const ScanIdle();
}

class ScanLoading extends ScanResultState {
  const ScanLoading();
}

class ScanSuccess extends ScanResultState {
  const ScanSuccess({required this.code, required this.result, required this.asGuest});
  final String code;
  final QrCodeScanResult result;

  /// 這次查詢是不是以訪客身分（不帶遊客 Token）送出的；是的話不會領取、也不能核銷。
  final bool asGuest;
}

class ScanNotFound extends ScanResultState {
  const ScanNotFound({required this.code, required this.message});
  final String code;
  final String message;
}

class ScanError extends ScanResultState {
  const ScanError({required this.message});
  final String message;
}

/// 使用者端：掃描 QR 碼查詢商家/優惠券資訊（功能二），並可核銷優惠券（功能三）。
///
/// 對應後端 `GET /api/qrcode/scan/{qrUid}` 與 `POST /api/coupons/{couponId}/redeem`。
/// NFC 貼紙序號跟相機掃到的 QR 碼內容都當成 qr_uid 查詢，後端 API 完全共用。
/// 以遊客帳號登入時，掃描會順便領取優惠券，之後才能核銷。
class UserScanPage extends StatefulWidget {
  const UserScanPage({super.key});

  @override
  State<UserScanPage> createState() => _UserScanPageState();
}

class _UserScanPageState extends State<UserScanPage> {
  final _nfcService = NfcService();
  final _qrService = QrService();
  final _repository = CouponRepository();

  ScanResultState _state = const ScanIdle();
  _ScanMethod _scanMethod = _ScanMethod.nfc;

  /// 訪客模式：不帶 Token 查詢，只看內容、不會寫入領取紀錄。
  bool _guestMode = false;
  bool _isRedeeming = false;

  bool get _isScanning => _state is ScanLoading;

  /// 後端只會幫「遊客」帳號領取優惠券，沒登入或用其他身分登入時一律當成訪客查詢。
  bool get _isTourist => AuthSession.info?.isTourist == true;

  Future<void> _startScan() async {
    final asGuest = _guestMode || !_isTourist;
    setState(() => _state = const ScanLoading());

    try {
      final String code;
      if (_scanMethod == _ScanMethod.nfc) {
        code = (await _nfcService.readOnce()).uidHex;
      } else {
        if (!context.mounted) return;
        code = await _qrService.scanOnce(context);
      }

      try {
        final result = await _repository.scanQrCode(code, asGuest: asGuest);
        if (!mounted) return;
        setState(() => _state = ScanSuccess(code: code, result: result, asGuest: asGuest));
      } on ApiFailure catch (e) {
        if (!mounted) return;
        setState(() {
          _state = e.isNotFound ? ScanNotFound(code: code, message: e.message) : ScanError(message: e.message);
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _state = ScanError(message: e.message));
      }
    } on NfcReadFailure catch (e) {
      if (!mounted) return;
      setState(() => _state = ScanError(message: e.message));
    } on QrReadCancelled {
      if (!mounted) return;
      setState(() => _state = const ScanIdle());
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = ScanError(message: '發生未預期的錯誤：$e'));
    } finally {
      if (_scanMethod == _ScanMethod.nfc) await _nfcService.stopSession();
    }
  }

  Future<void> _redeem(int couponId) async {
    setState(() => _isRedeeming = true);
    try {
      await _repository.redeemCoupon(couponId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('優惠券核銷成功')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  @override
  void dispose() {
    _nfcService.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用者：掃描 / 領取 / 核銷')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SegmentedButton<_ScanMethod>(
                segments: const [
                  ButtonSegment(value: _ScanMethod.nfc, label: Text('NFC 貼紙'), icon: Icon(Icons.nfc)),
                  ButtonSegment(value: _ScanMethod.qr, label: Text('QR 碼'), icon: Icon(Icons.qr_code_scanner)),
                ],
                selected: {_scanMethod},
                onSelectionChanged: _isScanning
                    ? null
                    : (selection) => setState(() => _scanMethod = selection.first),
              ),
              const SizedBox(height: 12),
              Text(
                _scanMethod == _ScanMethod.nfc
                    ? '按下「掃描」後，將手機背面靠近店家的 NFC 貼紙，\nApp 會讀取貼紙序號並查詢對應的商家資訊與優惠券。'
                    : '按下「掃描」後，將相機對準店家的 QR 碼，\nApp 會讀取 QR 碼內容並查詢對應的商家資訊與優惠券。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_isTourist)
                SwitchListTile(
                  title: const Text('以訪客身份查詢'),
                  subtitle: const Text('不會自動登記領取優惠券'),
                  value: _guestMode,
                  onChanged: _isScanning ? null : (value) => setState(() => _guestMode = value),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '目前沒有以遊客帳號登入，只能查看內容；\n回首頁登入遊客帳號後才會領取優惠券、才能核銷。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              FilledButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: Icon(_scanMethod == _ScanMethod.nfc ? Icons.nfc : Icons.qr_code_scanner),
                label: Text(_isScanning ? '掃描中...' : '掃描'),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(child: _buildResult(_state)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(ScanResultState state) {
    return switch (state) {
      ScanIdle() => const SizedBox.shrink(),
      ScanLoading() => const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Column(children: [CircularProgressIndicator()]),
      ),
      ScanSuccess(:final code, :final result, :final asGuest) => _buildSuccess(code, result, asGuest: asGuest),
      ScanNotFound(:final code, :final message) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            const Icon(Icons.help_outline, size: 48),
            const SizedBox(height: 8),
            const Text('這個 QR 碼尚未啟用，請洽店家', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('掃描到的代碼：$code'),
          ],
        ),
      ),
      ScanError(:final message) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    };
  }

  Widget _buildSuccess(String code, QrCodeScanResult result, {required bool asGuest}) {
    final place = result.merchantPlace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (place != null) ...[MerchantPlaceCard(place: place), const SizedBox(height: 12)],
        CouponCard(coupon: result.coupon),
        const SizedBox(height: 12),
        if (!asGuest)
          Text(
            result.isNewlyClaimed ? '已幫你登記領取這張優惠券' : '你之前已經領過這張優惠券了',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: asGuest || _isRedeeming ? null : () => _redeem(result.coupon.couponId),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(_isRedeeming ? '核銷中...' : '到店核銷這張優惠券'),
        ),
        if (asGuest)
          Text(
            _isTourist ? '訪客模式無法核銷，請關閉訪客模式後重新掃描' : '請先登入遊客帳號再重新掃描，才能領取與核銷',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        const SizedBox(height: 8),
        Text('掃描到的代碼：$code', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
