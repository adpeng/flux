import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_config.dart';
import '../services/v2board_api.dart';
import '../theme/app_colors.dart';

import '../widgets/gradient_card.dart';
import '../widgets/animated_background.dart';
import '../widgets/flux_loader.dart';

enum AuthMode { login, register, reset }

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthed;
  const AuthScreen({super.key, required this.onAuthed});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _ButtonLoader extends StatefulWidget {
  const _ButtonLoader();

  @override
  State<_ButtonLoader> createState() => _ButtonLoaderState();
}

class _ButtonLoaderState extends State<_ButtonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final shimmerX = (_controller.value * 2 - 1) * 1.2;
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2B2F36), Color(0xFF1C1F26)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                FractionalTranslation(
                  translation: Offset(shimmerX, 0),
                  child: Container(
                    width: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x22FFFFFF),
                          Color(0x88FFFFFF),
                          Color(0x22FFFFFF),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _api = V2BoardApi();
  final _config = ApiConfig();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _recaptchaController = TextEditingController();
  final _newPasswordController = TextEditingController();
  AuthMode _mode = AuthMode.login;
  bool _loading = false;
  String? _message;
  late final AnimationController _enterController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _inviteController.dispose();
    _emailCodeController.dispose();
    _recaptchaController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      HapticFeedback.lightImpact();
      Map<String, dynamic> response;
      if (_mode == AuthMode.login) {
        response = await _api.login(
          _emailController.text,
          _passwordController.text,
        );
      } else if (_mode == AuthMode.register) {
        response = await _api.register(
          _emailController.text,
          _passwordController.text,
          inviteCode: _inviteController.text,
          emailCode: _emailCodeController.text,
          recaptchaData: _recaptchaController.text,
        );
      } else {
        response = await _api.forgetPassword(
          _emailController.text,
          _emailCodeController.text,
          _newPasswordController.text,
        );
      }

      final token = (response['data'] ?? {})['token'];
      if (token is String && token.isNotEmpty) {
        await _config.setToken(token);
        // 确保 token 保存后立即刷新缓存
        await _config.refreshAuthCache();
      }
      final authData = (response['data'] ?? {})['auth_data'];
      if (authData is String && authData.isNotEmpty) {
        await _config.setAuthData(authData);
        // 确保 authData 保存后立即刷新缓存
        await _config.refreshAuthCache();
      }
      // 添加短暂延迟，确保数据已完全保存
      await Future.delayed(const Duration(milliseconds: 100));
      widget.onAuthed();
    } catch (e) {
      final msg = e is V2BoardApiException ? e.message : e.toString();
      setState(() {
        _message = msg;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendVerify() async {
    setState(() => _message = null);
    try {
      HapticFeedback.selectionClick();
      await _api.sendEmailVerify(
        _emailController.text,
        recaptchaData: _recaptchaController.text,
      );
      setState(() => _message = '验证码已发送');
    } catch (e) {
      final msg = e is V2BoardApiException ? e.message : e.toString();
      setState(() => _message = '发送失败: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background, // 确保纯黑背景
        body: Stack(
          children: [
            // 0. 纯黑底层 (确保无闪烁)
            Positioned.fill(
              child: Container(color: AppColors.background),
            ),
            // 1. Dynamic Background (Fade In to match Splash's blackness)
            Positioned.fill(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _enterController,
                  curve: Curves.easeIn,
                ),
                child: const AnimatedMeshBackground(
                  child: SizedBox.expand(),
                ),
              ),
            ),
          
          // Content
          LayoutBuilder(
            builder: (context, constraints) {
              final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                           AnimatedSize(
                             duration: const Duration(milliseconds: 200),
                             curve: Curves.easeOut,
                             child: SizedBox(height: isKeyboardOpen ? 24 : 48),
                           ),
                          // Logo / Header
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isKeyboardOpen ? 32 : 48,
                            height: isKeyboardOpen ? 32 : 48,
                            child: Icon(
                              Icons.blur_on,
                              size: isKeyboardOpen ? 32 : 48,
                              color: AppColors.accent,
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                             child: SizedBox(height: isKeyboardOpen ? 8 : 16),
                          ),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Roboto', 
                              fontSize: isKeyboardOpen ? 24 : 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 2,
                            ),
                            child: const Text('Flux'),
                          ),
                           AnimatedSize(
                             duration: const Duration(milliseconds: 200),
                             curve: Curves.easeOut,
                             child: SizedBox(height: isKeyboardOpen ? 24 : 48),
                           ),

                          // Auth Card
                          GradientCard(
                            padding: const EdgeInsets.all(32),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      _mode == AuthMode.reset
                                          ? '重置密码'
                                          : _mode == AuthMode.login
                                              ? '欢迎回来'
                                              : '创建账户',
                                      key: ValueKey(_mode),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  
                                  // Input Fields
                                  _buildTextField(
                                    controller: _emailController,
                                    label: '邮箱',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 16),
                                  if (_mode != AuthMode.login && _mode != AuthMode.reset) ...[
                                     _buildTextField(
                                      controller: _inviteController,
                                      label: '邀请码 (选填)',
                                      icon: Icons.card_giftcard,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_mode != AuthMode.login) ...[
                                    _buildTextField(
                                      controller: _emailCodeController,
                                      label: '验证码',
                                      icon: Icons.verified_user_outlined,
                                      suffix: TextButton(
                                        onPressed: _sendVerify,
                                        child: Text(
                                          '发送验证码',
                                          style: TextStyle(color: AppColors.accent),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                     if (_mode == AuthMode.register) ...[
                                        _buildTextField(
                                          controller: _recaptchaController,
                                          label: '人机验证 (选填)',
                                          icon: Icons.security,
                                        ),
                                        const SizedBox(height: 16),
                                     ],
                                  ],
                                  _buildTextField(
                                    controller: _mode == AuthMode.reset ? _newPasswordController : _passwordController,
                                    label: _mode == AuthMode.reset ? '新密码' : '密码',
                                    icon: Icons.lock_outline,
                                    obscureText: true,
                                  ),

                                  const SizedBox(height: 32),
                                  
                                  // Submit Button
                                  if (_message != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Text(
                                        _message!,
                                        style: const TextStyle(color: AppColors.accentWarm, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                  SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: FluxLoader(size: 24, color: Colors.black),
                                            )
                                          : Text(
                                              _mode == AuthMode.reset
                                                  ? '重置密码'
                                                  : _mode == AuthMode.login
                                                      ? '立即登录'
                                                      : '注册账户',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Toggle Mode Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_mode == AuthMode.reset)
                                TextButton(
                                  onPressed: () => setState(() => _mode = AuthMode.login),
                                  child: const Text('返回登录'),
                                )
                              else ...[
                                TextButton(
                                  onPressed: () => setState(() {
                                     _mode = _mode == AuthMode.login ? AuthMode.register : AuthMode.login;
                                  }),
                                  child: Text(
                                    _mode == AuthMode.login ? '没有账号? 去注册' : '已有账号? 去登录',
                                    style: TextStyle(
                                      color: AppColors.accent.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                                if (_mode == AuthMode.login) ...[
                                  Container(
                                    width: 1,
                                    height: 12,
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    color: AppColors.border,
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _mode = AuthMode.reset),
                                    child: const Text(
                                      '忘记密码',
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        ],
      ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          isDense: true,
        ),
      ),
    );
  }
}
