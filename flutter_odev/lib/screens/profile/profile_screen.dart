import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/study_stats.dart';
import '../../services/validators.dart';
import '../../state/auth_controller.dart';
import '../../state/data_controllers.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../auth/auth_layout.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Çıkış yapılsın mı?',
      message: 'Verilerin cihazda kalır; tekrar giriş yaptığında kaldığın yerden devam edersin.',
      confirmLabel: 'Çıkış yap',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    final auth = context.read<AuthController>();
    Navigator.of(context).popUntil((r) => r.isFirst);
    await auth.logout();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final password = await showDialog<String>(context: context, builder: (_) => const _DeleteAccountDialog());
    if (password == null || !context.mounted) return;
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final error = await auth.deleteAccount(password);
    if (!context.mounted) return;
    if (error != null) {
      showSnack(context, error);
      return;
    }
    navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const Scaffold();
    final scheme = Theme.of(context).colorScheme;
    final sessions = context.watch<SessionController>().sessions;
    final tasks = context.watch<TaskController>().tasks;
    final courses = context.watch<CourseController>().courses;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  UserAvatar(initials: user.initials, size: 76),
                  const SizedBox(height: 12),
                  Text(user.fullName, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text('@${user.username} · ${user.email}', style: TextStyle(color: scheme.onSurfaceVariant)),
                  if (user.school.isNotEmpty || user.department.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      [user.school, user.department].where((s) => s.isNotEmpty).join('\n'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('Üyelik: ${formatDate(user.createdAt)}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.hourglass_bottom_rounded,
                  color: scheme.primary,
                  value: formatMinutesShort(StudyStats.totalMinutes(sessions)),
                  label: 'Toplam çalışma',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xFF10B981),
                  value: '${tasks.where((t) => t.isDone).length}',
                  label: 'Biten görev',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.class_rounded,
                  color: const Color(0xFFF59E0B),
                  value: '${courses.length}',
                  label: 'Ders',
                ),
              ),
            ],
          ),
          const SectionHeader(title: 'Hesap'),
          CardList(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Profili düzenle'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditProfileScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Şifre değiştir'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Ayarlar'),
                subtitle: const Text('Tema, günlük hedef, odak süreleri'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Hakkında'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Avuçlu Hoca',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.auto_stories_rounded, size: 40),
                  children: const [
                    Text('Ders, ödev, not ortalaması ve odak süresi takibi için Flutter ile geliştirilmiş öğrenci asistanı. '
                        'Bütün veriler yalnızca bu cihazda saklanır.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CardList(
            children: [
              ListTile(
                key: const Key('logout'),
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Çıkış yap'),
                onTap: () => _logout(context),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
                title: Text('Hesabı sil', style: TextStyle(color: scheme.error)),
                onTap: () => _deleteAccount(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hesabı sil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Hesabın; derslerin, görevlerin ve çalışma kayıtlarınla birlikte kalıcı olarak silinecek. '
              'Onaylamak için şifreni gir.'),
          const SizedBox(height: 14),
          PasswordField(controller: _password),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, _password.text),
          child: const Text('Kalıcı olarak sil'),
        ),
      ],
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _school;
  late final TextEditingController _department;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser!;
    _name = TextEditingController(text: user.fullName);
    _email = TextEditingController(text: user.email);
    _school = TextEditingController(text: user.school);
    _department = TextEditingController(text: user.department);
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _school, _department]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await context.read<AuthController>().updateProfile(
          fullName: _name.text,
          email: _email.text,
          school: _school.text,
          department: _department.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    showSnack(context, 'Profil güncellendi.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profili düzenle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad soyad', prefixIcon: Icon(Icons.badge_outlined)),
              validator: Validators.fullName,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _school,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Okul', prefixIcon: Icon(Icons.account_balance_outlined)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _department,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Bölüm', prefixIcon: Icon(Icons.school_outlined)),
            ),
            if (_error != null) ...[const SizedBox(height: 14), ErrorBanner(message: _error!)],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Kaydet')),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await context.read<AuthController>().changePassword(current: _current.text, newPassword: _password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    showSnack(context, 'Şifren değiştirildi.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifre değiştir')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            PasswordField(
              controller: _current,
              label: 'Mevcut şifre',
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.isEmpty) ? 'Mevcut şifreni gir.' : null,
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
              onSubmitted: (_) => _save(),
              validator: Validators.confirmPassword(() => _password.text),
            ),
            if (_error != null) ...[const SizedBox(height: 14), ErrorBanner(message: _error!)],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Şifreyi değiştir'),
            ),
          ],
        ),
      ),
    );
  }
}
