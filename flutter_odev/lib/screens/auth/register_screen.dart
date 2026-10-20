import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/validators.dart';
import '../../state/auth_controller.dart';
import '../../utils/text_utils.dart';
import '../../widgets/common.dart';
import 'auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _answer = TextEditingController();
  final _school = TextEditingController();
  final _department = TextEditingController();
  String _question = securityQuestions.first;
  bool _accepted = false;
  bool _showTermsError = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_fullName, _username, _email, _password, _confirm, _answer, _school, _department]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_accepted);
    if (!valid || !_accepted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await context.read<AuthController>().register(
          fullName: _fullName.text,
          username: _username.text,
          email: _email.text,
          password: _password.text,
          securityQuestion: _question,
          securityAnswer: _answer.text,
          school: _school.text,
          department: _department.text,
        );
    if (!mounted) return;
    if (error == null) {
      // Oturum açıldı; kök widget ana sayfayı gösterecek. Bu ekranı kapat.
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    return AuthLayout(
      showBack: true,
      title: 'Hesap oluştur',
      subtitle: 'Birkaç bilgiyle başla; verilerin yalnızca bu cihazda saklanır.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GroupLabel('Hesap bilgileri'),
              TextFormField(
                key: const Key('register-fullname'),
                controller: _fullName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Ad soyad',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: Validators.fullName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register-username'),
                controller: _username,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.newUsername],
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı adı',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  helperText: '3-20 karakter: harf, rakam, nokta, alt çizgi',
                ),
                validator: Validators.username,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register-email'),
                controller: _email,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: Validators.email,
              ),
              const _GroupLabel('Şifre'),
              PasswordField(
                key: const Key('register-password'),
                controller: _password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                validator: Validators.password,
              ),
              PasswordStrengthMeter(password: _password.text),
              const SizedBox(height: 14),
              PasswordField(
                key: const Key('register-confirm'),
                controller: _confirm,
                label: 'Şifre (tekrar)',
                textInputAction: TextInputAction.next,
                validator: Validators.confirmPassword(() => _password.text),
              ),
              const _GroupLabel('Hesap kurtarma'),
              DropdownButtonFormField<String>(
                initialValue: _question,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Güvenlik sorusu',
                  prefixIcon: Icon(Icons.help_outline_rounded),
                ),
                items: [
                  for (final q in securityQuestions)
                    DropdownMenuItem(value: q, child: Text(q, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _question = v ?? _question),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register-answer'),
                controller: _answer,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Cevabın',
                  prefixIcon: Icon(Icons.key_rounded),
                  helperText: 'Şifreni unutursan bu cevapla sıfırlayabilirsin.',
                ),
                validator: (v) => Validators.required(v, 'Güvenlik sorusunu cevapla.'),
              ),
              const _GroupLabel('Okul bilgileri (isteğe bağlı)'),
              TextFormField(
                controller: _school,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Okul',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _department,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Bölüm',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                key: const Key('register-terms'),
                value: _accepted,
                onChanged: (v) => setState(() {
                  _accepted = v ?? false;
                  if (_accepted) _showTermsError = false;
                }),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('Verilerimin yalnızca bu cihazda saklandığını ve şifremin özetlenerek korunduğunu anladım.'),
                subtitle: _showTermsError
                    ? Text('Devam etmek için onaylaman gerekiyor.', style: TextStyle(color: scheme.error))
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('register-submit'),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Kayıt Ol'),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Zaten hesabın var mı?'),
                  TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Giriş yap')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 0, 10),
      child: Text(
        trUpper(text),
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
