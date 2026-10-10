import 'package:flutter/material.dart';

import '../config/auth_session.dart';
import '../models/login_info.dart';
import 'login_page.dart';
import 'merchant_bind_page.dart';
import 'user_scan_page.dart';

/// 進入 App 後先選擇身分：使用者（掃描/領取/核銷優惠券）或商家（綁定 QR Code）。
///
/// 使用者不登入也能掃描查看內容，以遊客帳號登入才會領取優惠券、才能核銷；
/// 商家綁定一定要用商家帳號登入（後端從 Token 取得店家代號）。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _openMerchantPage(BuildContext context) async {
    if (AuthSession.info?.isMerchant != true) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginPage(hint: '綁定 QR Code 需要商家帳號，請先登入。')),
      );
      if (!context.mounted || loggedIn != true) return;
      if (AuthSession.info?.isMerchant != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('這個帳號不是商家帳號，無法綁定 QR Code')));
        return;
      }
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MerchantBindPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商家優惠券示意')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<LoginInfo?>(
                  valueListenable: AuthSession.current,
                  builder: (context, info, _) => _buildLoginStatus(context, info),
                ),
                const SizedBox(height: 32),
                const Text('請選擇要示範的身分', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserScanPage()));
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('使用者：掃描 / 領取 / 核銷'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _openMerchantPage(context),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('商家：綁定貼紙 / 產生代碼'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginStatus(BuildContext context, LoginInfo? info) {
    if (info == null) {
      return Column(
        children: [
          const Text('尚未登入：可以掃描查看內容，但不會領取優惠券', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: () => _openLogin(context), icon: const Icon(Icons.login), label: const Text('登入')),
        ],
      );
    }
    return Column(
      children: [
        Text('已登入：${info.authName}（${info.roleLabel}）', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: AuthSession.signOut, icon: const Icon(Icons.logout), label: const Text('登出')),
      ],
    );
  }
}
