import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../../widgets/common.dart';
import 'auth_layout.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifier;
  final _password = TextEditingController();
  bool _rememberMe = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _identifier = TextEditingController(text: context.read<AuthController>().lastIdentifier ?? '');
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await context.read<AuthController>().login(
          identifier: _identifier.text,
          password: _password.text,
          rememberMe: _rememberMe,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  Future<void> _demo() async {
    setState(() => _loading = true);
    await context.read<AuthController>().loginDemo();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AuthLayout(
      title: 'Tekrar hoş geldin',
      subtitle: 'Derslerini ve ödevlerini takip etmek için giriş yap.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('login-identifier'),
                controller: _identifier,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı adı veya e-posta',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Kullanıcı adını veya e-postanı gir.' : null,
              ),
              const SizedBox(height: 14),
              PasswordField(
                key: const Key('login-password'),
                controller: _password,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.isEmpty) ? 'Şifreni gir.' : null,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? true),
                          ),
                          const Flexible(child: Text('Beni hatırla')),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ForgotPasswordScreen(initialIdentifier: _identifier.text),
                      ),
                    ),
                    child: const Text('Şifremi unuttum'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('login-submit'),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Giriş Yap'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('veya', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _loading ? null : _demo,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Demo hesabıyla dene'),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Hesabın yok mu?'),
                  TextButton(
                    key: const Key('go-register'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Kayıt ol'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
