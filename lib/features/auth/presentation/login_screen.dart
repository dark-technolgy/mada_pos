import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/l10n_ext.dart';
import '../application/login_service.dart';
import '../../../core/security/account_security_service.dart';
import '../../../core/security/password_validation.dart';
import '../../../core/theme/app_colors.dart';
import 'change_password_dialog.dart';
import 'widgets/login_sections.dart';
import '../../../shared/providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  final LoginService _loginService = const LoginService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final l10n = context.l10n;
      final db = ref.read(databaseProvider);
      final password = _passwordController.text;
      final loginResult = await _loginService.authenticate(
        db,
        username: _usernameController.text,
        password: password,
      );

      if (loginResult.status == LoginStatus.invalidCredentials ||
          loginResult.user == null) {
        setState(() {
          _errorMessage = l10n.invalidCredentials;
          _isLoading = false;
        });
        return;
      }

      var authenticatedUser = loginResult.user!;

      if (loginResult.status == LoginStatus.passwordChangeRequired) {
        if (!mounted) return;

        final result = await ChangePasswordDialog.show(
          context,
          requireCurrentPassword: false,
          isMandatory: true,
        );

        if (result == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        try {
          authenticatedUser = await _loginService
              .completeMandatoryPasswordChange(
                db,
                user: authenticatedUser,
                newPassword: result.newPassword,
              );
        } on AccountSecurityException catch (error) {
          setState(() {
            _errorMessage =
                passwordValidationMessage(l10n, error.message) ?? error.message;
            _isLoading = false;
          });
          return;
        }
      }

      // Start session
      final session = ref.read(sessionManagerProvider);
      await session.startSession(authenticatedUser);

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = context.l10n.errorOccurred;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            _login();
          }
        },
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Row(
              children: [
                if (size.width > 900)
                  LoginBrandingPanel(
                    appName: l10n.appName,
                    subtitle: l10n.smartSalesSystem,
                    features: [
                      LoginFeatureEntry(
                        icon: Icons.speed_rounded,
                        label: l10n.fastAndSmart,
                      ),
                      LoginFeatureEntry(
                        icon: Icons.security_rounded,
                        label: l10n.highSecurity,
                      ),
                      LoginFeatureEntry(
                        icon: Icons.language_rounded,
                        label: l10n.multilingual,
                      ),
                      LoginFeatureEntry(
                        icon: Icons.inventory_rounded,
                        label: l10n.comprehensiveManagement,
                      ),
                    ],
                  ),
                LoginFormPanel(
                  size: size,
                  formKey: _formKey,
                  usernameController: _usernameController,
                  passwordController: _passwordController,
                  usernameLabel: l10n.username,
                  passwordLabel: l10n.password,
                  enterUsernameLabel: l10n.enterUsername,
                  enterPasswordLabel: l10n.enterPassword,
                  welcomeLabel: '${l10n.welcomeBack} 👋',
                  signInLabel: l10n.signInToContinue,
                  loginButtonLabel: l10n.loginButton,
                  footerLabel: '${l10n.versionLabel} 1.0.0 | Mada © 2026',
                  obscurePassword: _obscurePassword,
                  onTogglePassword: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  isLoading: _isLoading,
                  onSubmit: _login,
                  errorMessage: _errorMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
