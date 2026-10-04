import 'package:flutter/material.dart';

import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/core/widgets/furnexa_logo.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.security,
    required this.onLoggedIn,
    this.setupRequired = false,
  });

  final SecurityLocalDataSource security;
  final VoidCallback onLoggedIn;
  final bool setupRequired;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  bool _passwordVisible = false;
  late bool _setupRequired = widget.setupRequired;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_setupRequired || await widget.security.initialAdminSetupRequired()) {
        if (_password.text != _confirmPassword.text) {
          setState(
            () => _error = AppLocalizations.of(context).passwordMismatch,
          );
          return;
        }
        if (_password.text.length <
            SecurityLocalDataSource.minimumInitialAdminPasswordLength) {
          setState(
            () => _error = AppLocalizations.of(
              context,
            ).initialAdminPasswordTooShort,
          );
          return;
        }
        await widget.security.setupInitialAdmin(
          username: _username.text,
          displayName: _username.text,
          password: _password.text,
        );
      }
      await widget.security.login(_username.text, _password.text);
      await FurnexaDatabaseDiagnostics.capture(
        source: 'auth.login.completedBeforeNavigation',
      );
      if (mounted) widget.onLoggedIn();
    } catch (_) {
      if (mounted) {
        final setupRequired = await widget.security.initialAdminSetupRequired();
        setState(() {
          _setupRequired = setupRequired;
          _error = AppLocalizations.of(context).invalidCredentials;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textDirection = Directionality.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppTheme.darkBackground, AppTheme.darkSurface]
                : [AppTheme.navy, AppTheme.graphite],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FurnexaLogo(
                        compact: false,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.navy,
                      ),
                      const SizedBox(height: 28),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          _setupRequired
                              ? localizations.setupAdministrator
                              : localizations.login,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _username,
                        textDirection: textDirection,
                        textAlign: textDirection == TextDirection.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        decoration: InputDecoration(
                          labelText: localizations.username,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      if (_setupRequired) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _confirmPassword,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: localizations.confirmPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: !_passwordVisible,
                        textDirection: textDirection,
                        textAlign: textDirection == TextDirection.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: localizations.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _login,
                          icon: const Icon(Icons.login_outlined),
                          label: Text(
                            _loading
                                ? localizations.loggingIn
                                : _setupRequired
                                ? localizations.setupAdmin
                                : localizations.login,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
