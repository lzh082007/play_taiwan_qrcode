import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../repositories/auth_repository.dart';

/// 登入頁：遊客、商家共用同一支登入 API，登入成功後回傳 `true` 並關閉頁面。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.hint});

  /// 顯示在表單上方的說明，例如「綁定 QR Code 需要商家帳號」。
  final String? hint;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _repository = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _repository.login(account: _accountController.text.trim(), password: _passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = '發生未預期的錯誤：$e';
      });
    }
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint;
    return Scaffold(
      appBar: AppBar(title: const Text('登入')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hint != null) ...[Text(hint, textAlign: TextAlign.center), const SizedBox(height: 16)],
                TextFormField(
                  controller: _accountController,
                  enabled: !_isSubmitting,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: '帳號名稱或信箱', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.trim().isEmpty) ? '請輸入帳號名稱或信箱' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isSubmitting,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: '密碼', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.isEmpty) ? '請輸入密碼' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _isSubmitting ? null : _submit, child: Text(_isSubmitting ? '登入中...' : '登入')),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '伺服器：${ApiConfig.baseUrl}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
