import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/ui/app_breakpoints.dart';
import '../../../../core/widgets/brand_avatar.dart';
import '../providers/auth_provider.dart';
import '../../../school/presentation/providers/school_context_provider.dart';

enum _LoginMode { account, phone, wechat }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _lastLoginEmailKey = 'last_login_email';
  static const _lastLoginPhoneKey = 'last_login_phone';
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  _LoginMode _loginMode = _LoginMode.account;
  bool _codeRequested = false;

  @override
  void initState() {
    super.initState();
    _restoreLastLoginIdentity();
  }

  Future<void> _restoreLastLoginIdentity() async {
    final preferences = await SharedPreferences.getInstance();
    final lastEmail = preferences.getString(_lastLoginEmailKey);
    final lastPhone = preferences.getString(_lastLoginPhoneKey);
    if (!mounted) {
      return;
    }
    if (lastEmail != null && lastEmail.trim().isNotEmpty) {
      _emailController.text = lastEmail.trim();
    }
    if (lastPhone != null && lastPhone.trim().isNotEmpty) {
      _phoneController.text = lastPhone.trim();
    }
  }

  Future<void> _saveLastLoginIdentity() async {
    final email = _emailController.text.trim();
    final preferences = await SharedPreferences.getInstance();
    if (email.isNotEmpty) {
      await preferences.setString(_lastLoginEmailKey, email);
    }
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      await preferences.setString(_lastLoginPhoneKey, phone);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
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
        _saveLastLoginIdentity();
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
          child: LayoutBuilder(
            builder: (context, viewport) {
              final contentMaxWidth = responsiveWidthCap(
                viewport.maxWidth,
                fraction: 0.94,
                min: 320.0,
                max: 1040.0,
              );
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
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
                            padding: EdgeInsets.all(isPhone ? 14 : 22),
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
                                        phoneController: _phoneController,
                                        codeController: _codeController,
                                        loginMode: _loginMode,
                                        codeRequested: _codeRequested,
                                        isLoading: authState.isLoading,
                                        onModeChanged: _switchLoginMode,
                                        onLogin: _onLogin,
                                        onRequestCode: _onRequestPhoneCode,
                                        onWechatLogin: _onWechatLogin,
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
                                            passwordController:
                                                _passwordController,
                                            phoneController: _phoneController,
                                            codeController: _codeController,
                                            loginMode: _loginMode,
                                            codeRequested: _codeRequested,
                                            isLoading: authState.isLoading,
                                            onModeChanged: _switchLoginMode,
                                            onLogin: _onLogin,
                                            onRequestCode: _onRequestPhoneCode,
                                            onWechatLogin: _onWechatLogin,
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
              );
            },
          ),
        ),
      ),
    );
  }

  void _switchLoginMode(_LoginMode mode) {
    setState(() {
      _loginMode = mode;
    });
  }

  Future<void> _onLogin() async {
    if (_formKey.currentState!.validate()) {
      if (_loginMode == _LoginMode.phone) {
        await ref
            .read(authProvider.notifier)
            .verifyPhoneCode(
              _phoneController.text.trim(),
              _codeController.text.trim(),
            );
        return;
      }
      ref
          .read(authProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text.trim());
    }
  }

  Future<void> _onRequestPhoneCode() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入手机号')));
      return;
    }
    final success = await ref
        .read(authProvider.notifier)
        .requestPhoneCode(_phoneController.text.trim());
    if (!mounted || !success) {
      return;
    }
    setState(() {
      _codeRequested = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('验证码已发送，请查看家长手机')));
  }

  void _onWechatLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('家长微信授权登录正在接入中，请先使用账号或验证码登录。')),
    );
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
      padding: EdgeInsets.all(isPhone ? 16 : 24),
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
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: BrandAvatar(
                  logoUrl: schoolContext.logoUrl,
                  size: isPhone ? 54 : 64,
                  borderRadius: 22,
                  backgroundColor: Colors.transparent,
                  fallbackIcon: Icons.auto_stories_rounded,
                  fallbackIconColor: Colors.white,
                  fallbackIconSize: isPhone ? 28 : 32,
                ),
              ),
              if (schoolContext.displayName.isNotEmpty) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    schoolContext.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (isPhone
                                ? Theme.of(context).textTheme.headlineSmall
                                : Theme.of(context).textTheme.displaySmall)
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                  ),
                ),
              ],
            ],
          ),
          if (!isPhone) ...[
            const SizedBox(height: 18),
            Text(
              '学生登录',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.96),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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
    required this.phoneController,
    required this.codeController,
    required this.loginMode,
    required this.codeRequested,
    required this.isLoading,
    required this.onModeChanged,
    required this.onLogin,
    required this.onRequestCode,
    required this.onWechatLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final _LoginMode loginMode;
  final bool codeRequested;
  final bool isLoading;
  final ValueChanged<_LoginMode> onModeChanged;
  final VoidCallback onLogin;
  final VoidCallback onRequestCode;
  final VoidCallback onWechatLogin;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LoginModeSwitcher(selectedMode: loginMode, onChanged: onModeChanged),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (loginMode) {
              _LoginMode.account => _AccountLoginFields(
                key: const ValueKey('account-login'),
                emailController: emailController,
                passwordController: passwordController,
              ),
              _LoginMode.phone => _PhoneLoginFields(
                key: const ValueKey('phone-login'),
                phoneController: phoneController,
                codeController: codeController,
                codeRequested: codeRequested,
                isLoading: isLoading,
                onRequestCode: onRequestCode,
              ),
              _LoginMode.wechat => _WechatLoginPane(
                key: const ValueKey('wechat-login'),
                onWechatLogin: onWechatLogin,
              ),
            },
          ),
          const SizedBox(height: 22),
          if (loginMode != _LoginMode.wechat)
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
                    : Text(loginMode == _LoginMode.phone ? '验证并登录' : '登录'),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoginModeSwitcher extends StatelessWidget {
  const _LoginModeSwitcher({
    required this.selectedMode,
    required this.onChanged,
  });

  final _LoginMode selectedMode;
  final ValueChanged<_LoginMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (mode: _LoginMode.account, icon: Icons.badge_rounded, label: '账号'),
      (mode: _LoginMode.phone, icon: Icons.sms_rounded, label: '验证码'),
      (mode: _LoginMode.wechat, icon: Icons.wechat_rounded, label: '家长微信'),
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onChanged(item.mode),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedMode == item.mode
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: selectedMode == item.mode
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF2E7BEF,
                                ).withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: selectedMode == item.mode
                              ? const Color(0xFF2E7BEF)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: selectedMode == item.mode
                                      ? const Color(0xFF17335F)
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountLoginFields extends StatelessWidget {
  const _AccountLoginFields({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: '用户名 / 邮箱',
            prefixIcon: Icon(Icons.account_circle_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入用户名或邮箱';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '登录密码',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入登录密码';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _PhoneLoginFields extends StatelessWidget {
  const _PhoneLoginFields({
    super.key,
    required this.phoneController,
    required this.codeController,
    required this.codeRequested,
    required this.isLoading,
    required this.onRequestCode,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool codeRequested;
  final bool isLoading;
  final VoidCallback onRequestCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '家长手机号',
            prefixIcon: const Icon(Icons.phone_iphone_rounded),
            suffixIcon: TextButton(
              onPressed: isLoading ? null : onRequestCode,
              child: Text(codeRequested ? '重新发送' : '发送验证码'),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().length < 6) {
              return '请输入正确的手机号';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: codeController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '验证码',
            prefixIcon: Icon(Icons.pin_rounded),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入验证码';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _WechatLoginPane extends StatelessWidget {
  const _WechatLoginPane({super.key, required this.onWechatLogin});

  final VoidCallback onWechatLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBF1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBDECCB)),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              size: 58,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '家长微信授权',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF14532D),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onWechatLogin,
            icon: const Icon(Icons.wechat_rounded),
            label: const Text('生成授权二维码'),
          ),
        ],
      ),
    );
  }
}
