import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/widgets/brand_avatar.dart';
import '../providers/auth_provider.dart';
import '../../../school/presentation/providers/school_context_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _lastLoginEmailKey = 'last_login_email';
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreLastLoginEmail();
  }

  Future<void> _restoreLastLoginEmail() async {
    final preferences = await SharedPreferences.getInstance();
    final lastEmail = preferences.getString(_lastLoginEmailKey);
    if (!mounted || lastEmail == null || lastEmail.trim().isEmpty) {
      return;
    }
    _emailController.text = lastEmail.trim();
  }

  Future<void> _saveLastLoginEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastLoginEmailKey, email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    ref.listen(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if ((previous?.isAuthenticated ?? false) == false &&
          next.isAuthenticated) {
        _saveLastLoginEmail();
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              schoolContext.primaryColor.withValues(alpha: 0.92),
              schoolContext.secondaryColor.withValues(alpha: 0.88),
              const Color(0xFFF6F7FB),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isPhone = constraints.maxWidth < 720;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isPhone ? 14 : 24),
                    child: Card(
                      elevation: 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isPhone ? 16 : 24),
                        child: isPhone
                            ? Column(
                                children: [
                                  _SchoolHero(
                                    schoolContext: schoolContext,
                                    isPhone: true,
                                  ),
                                  const SizedBox(height: 18),
                                  _LoginForm(
                                    formKey: _formKey,
                                    emailController: _emailController,
                                    passwordController: _passwordController,
                                    isLoading: authState.isLoading,
                                    onLogin: _onLogin,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _SchoolHero(
                                      schoolContext: schoolContext,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: _LoginForm(
                                        formKey: _formKey,
                                        emailController: _emailController,
                                        passwordController: _passwordController,
                                        isLoading: authState.isLoading,
                                        onLogin: _onLogin,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onLogin() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(authProvider.notifier)
          .login(_emailController.text, _passwordController.text);
    }
  }
}

class _SchoolHero extends StatelessWidget {
  const _SchoolHero({required this.schoolContext, this.isPhone = false});

  final SchoolContext schoolContext;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isPhone ? 22 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [schoolContext.primaryColor, schoolContext.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
            ),
            child: BrandAvatar(
              logoUrl: schoolContext.logoUrl,
              size: isPhone ? 60 : 68,
              borderRadius: 22,
              backgroundColor: Colors.transparent,
              fallbackIcon: Icons.auto_stories_rounded,
              fallbackIconColor: Colors.white,
              fallbackIconSize: isPhone ? 30 : 34,
            ),
          ),
          SizedBox(height: schoolContext.displayName.isEmpty ? 16 : 20),
          if (schoolContext.displayName.isNotEmpty)
            Text(
              schoolContext.displayName,
              style:
                  (isPhone
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.displaySmall)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
            ),
          SizedBox(height: schoolContext.displayName.isEmpty ? 0 : 12),
          Text(
            schoolContext.welcomeTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.96),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            schoolContext.welcomeMessage,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '请使用学校老师或管理员发放的账号登录。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '欢迎回来',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            '登录后就能继续今天的英语打卡任务。',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入登录邮箱';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入登录密码';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onLogin,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登录'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '账号由机构管理员统一创建，请联系老师或管理员开通。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '如果这个账号同时属于多个学校，登录后系统会自动提示你选择。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
