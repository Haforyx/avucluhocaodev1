import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/validators.dart';
import '../../state/auth_controller.dart';
import '../../widgets/common.dart';
import 'auth_layout.dart';

/// İki adımlı şifre sıfırlama: önce hesap bulunur, sonra güvenlik sorusu
/// cevaplanıp yeni şifre belirlenir.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialIdentifier = ''});

  final String initialIdentifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _identifier = TextEditingController(text: widget.initialIdentifier);
  final _answer = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _question;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_identifier, _answer, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _findAccount() {
    if (!_formKey.currentState!.validate()) return;
    final question = context.read<AuthController>().securityQuestionFor(_identifier.text);
    setState(() {
      _question = question;
      _error = question == null ? 'Bu bilgilerle kayıtlı bir hesap bulunamadı.' : null;
    });
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await context.read<AuthController>().resetPassword(
          identifier: _identifier.text,
          answer: _answer.text,
          newPassword: _password.text,
        );
    if (!mounted) return;
    if (error == null) {
      showSnack(context, 'Şifren güncellendi. Yeni şifrenle giriş yapabilirsin.');
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final step2 = _question != null;
    return AuthLayout(
      showBack: true,
      title: 'Şifreni sıfırla',
      subtitle: step2
          ? 'Kayıt olurken seçtiğin soruyu cevapla ve yeni şifreni belirle.'
          : 'Hesabını bulmak için kullanıcı adını veya e-postanı yaz.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _identifier,
              enabled: !step2,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => step2 ? null : _findAccount(),
              decoration: const InputDecoration(
                labelText: 'Kullanıcı adı veya e-posta',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              validator: (v) => Validators.required(v, 'Kullanıcı adını veya e-postanı gir.'),
            ),
            if (step2) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.help_rounded, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _question!,
                        style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _answer,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Cevabın', prefixIcon: Icon(Icons.key_rounded)),
                validator: (v) => Validators.required(v, 'Cevabı yaz.'),
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                label: 'Yeni şifre',
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                validator: Validators.password,
              ),
              PasswordStrengthMeter(password: _password.text),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirm,
                label: 'Yeni şifre (tekrar)',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _reset(),
                validator: Validators.confirmPassword(() => _password.text),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : (step2 ? _reset : _findAccount),
              child: _loading
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(step2 ? 'Şifreyi Güncelle' : 'Devam'),
            ),
            if (step2)
              TextButton(
                onPressed: () => setState(() {
                  _question = null;
                  _error = null;
                }),
                child: const Text('Başka bir hesap'),
              ),
          ],
        ),
      ),
    );
  }
}
