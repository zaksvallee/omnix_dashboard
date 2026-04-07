import 'package:flutter/material.dart';

import '../domain/authority/onyx_route.dart';
import 'theme/onyx_design_tokens.dart';

class ControllerLoginAccount {
  final String username;
  final String password;
  final String displayName;
  final String roleLabel;
  final String accessLabel;
  final OnyxRoute landingRoute;

  const ControllerLoginAccount({
    required this.username,
    required this.password,
    required this.displayName,
    required this.roleLabel,
    required this.accessLabel,
    required this.landingRoute,
  });
}

class ControllerLoginPage extends StatefulWidget {
  final List<ControllerLoginAccount> demoAccounts;
  final ValueChanged<ControllerLoginAccount> onAuthenticated;
  final VoidCallback? onResetRequested;

  const ControllerLoginPage({
    super.key,
    required this.demoAccounts,
    required this.onAuthenticated,
    this.onResetRequested,
  });

  @override
  State<ControllerLoginPage> createState() => _ControllerLoginPageState();
}

class _ControllerLoginPageState extends State<ControllerLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorText = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    ControllerLoginAccount? match;
    for (final account in widget.demoAccounts) {
      if (account.username.toLowerCase() == username &&
          account.password.trim() == password) {
        match = account;
        break;
      }
    }
    if (match == null) {
      setState(() {
        _errorText = widget.demoAccounts.isEmpty
            ? 'Demo accounts are unavailable in this build.'
            : 'Use one of the demo accounts below to continue.';
      });
      return;
    }
    setState(() {
      _errorText = '';
    });
    widget.onAuthenticated(match);
  }

  void _fillDemoAccount(ControllerLoginAccount account) {
    setState(() {
      _usernameController.text = account.username;
      _passwordController.text = account.password.trim();
      _errorText = '';
    });
  }

  void _resetPreview() {
    setState(() {
      _usernameController.clear();
      _passwordController.clear();
      _errorText = '';
    });
    widget.onResetRequested?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('controller-login-page'),
      backgroundColor: OnyxDesignTokens.backgroundPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 880 ? 32.0 : 20.0;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Image.asset(
                          'assets/images/onyx_logo.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  OnyxRadiusTokens.xl,
                                ),
                                border: Border.all(
                                  color: OnyxDesignTokens.borderSubtle,
                                ),
                                color: OnyxDesignTokens.cardSurface,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 34,
                                color: OnyxDesignTokens.cyanInteractive,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'ONYX SECURITY',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: OnyxTypographyTokens.sansFamily,
                          color: OnyxDesignTokens.textPrimary,
                          fontSize: 38,
                          fontWeight: OnyxTypographyTokens.extrabold,
                          letterSpacing: OnyxTypographyTokens.trackingHeadline,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Operations Control Platform',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: OnyxTypographyTokens.sansFamily,
                          color: OnyxDesignTokens.textSecondary,
                          fontSize: OnyxTypographyTokens.bodyLg,
                          fontWeight: OnyxTypographyTokens.medium,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Controller Login',
                              style: const TextStyle(
                                fontFamily: OnyxTypographyTokens.sansFamily,
                                color: OnyxDesignTokens.textPrimary,
                                fontSize: OnyxTypographyTokens.titleMd,
                                fontWeight: OnyxTypographyTokens.extrabold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildLabel('Username'),
                            const SizedBox(height: 8),
                            _buildField(
                              key: const ValueKey('controller-login-username'),
                              controller: _usernameController,
                              hintText: 'Enter your username',
                              icon: Icons.person_outline_rounded,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 18),
                            _buildLabel('Password'),
                            const SizedBox(height: 8),
                            _buildField(
                              key: const ValueKey('controller-login-password'),
                              controller: _passwordController,
                              hintText: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            ),
                            if (_errorText.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                _errorText,
                                key: const ValueKey('controller-login-error'),
                                style: const TextStyle(
                                  fontFamily: OnyxTypographyTokens.sansFamily,
                                  color: OnyxDesignTokens.redCritical,
                                  fontSize: OnyxTypographyTokens.labelLg,
                                  fontWeight: OnyxTypographyTokens.semibold,
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const ValueKey('controller-login-submit'),
                                onPressed: _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      OnyxDesignTokens.cyanInteractive,
                                  foregroundColor:
                                      OnyxDesignTokens.backgroundPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      OnyxRadiusTokens.lg,
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: OnyxTypographyTokens.sansFamily,
                                    fontSize: OnyxTypographyTokens.titleMd,
                                    fontWeight: OnyxTypographyTokens.extrabold,
                                  ),
                                ),
                                child: const Text('Sign In'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DEMO ACCOUNTS',
                              style: const TextStyle(
                                fontFamily: OnyxTypographyTokens.sansFamily,
                                color: OnyxDesignTokens.textSecondary,
                                fontSize: OnyxTypographyTokens.labelLg,
                                fontWeight: OnyxTypographyTokens.extrabold,
                                letterSpacing:
                                    OnyxTypographyTokens.trackingCaps,
                              ),
                            ),
                            const SizedBox(height: 18),
                            for (final account in widget.demoAccounts) ...[
                              InkWell(
                                key: ValueKey(
                                  'controller-demo-account-${account.username}',
                                ),
                                onTap: () => _fillDemoAccount(account),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      OnyxRadiusTokens.md,
                                    ),
                                    border: Border.all(
                                      color: OnyxDesignTokens.borderSubtle,
                                    ),
                                    color: OnyxDesignTokens.backgroundSecondary,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 10,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              account.username,
                                              style: const TextStyle(
                                                fontFamily: OnyxTypographyTokens
                                                    .sansFamily,
                                                color: OnyxDesignTokens
                                                    .textPrimary,
                                                fontSize: OnyxTypographyTokens
                                                    .labelLg,
                                                fontWeight:
                                                    OnyxTypographyTokens.bold,
                                                letterSpacing:
                                                    OnyxTypographyTokens
                                                        .trackingLabel,
                                              ),
                                            ),
                                            Text(
                                              account.roleLabel,
                                              style: const TextStyle(
                                                fontFamily: OnyxTypographyTokens
                                                    .sansFamily,
                                                color: OnyxDesignTokens
                                                    .cyanInteractive,
                                                fontSize: OnyxTypographyTokens
                                                    .labelLg,
                                                fontWeight:
                                                    OnyxTypographyTokens.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        account.accessLabel,
                                        style: const TextStyle(
                                          fontFamily:
                                              OnyxTypographyTokens.sansFamily,
                                          color: OnyxDesignTokens.textSecondary,
                                          fontSize:
                                              OnyxTypographyTokens.labelLg,
                                          fontWeight:
                                              OnyxTypographyTokens.semibold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                key: const ValueKey('controller-login-reset'),
                                onPressed: _resetPreview,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: OnyxDesignTokens.redCritical,
                                  side: const BorderSide(
                                    color: OnyxDesignTokens.redBorder,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      OnyxRadiusTokens.md,
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: OnyxTypographyTokens.sansFamily,
                                    fontSize: OnyxTypographyTokens.bodyLg,
                                    fontWeight: OnyxTypographyTokens.bold,
                                  ),
                                ),
                                child: const Text('Clear Cache & Reset'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: OnyxDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(OnyxRadiusTokens.panel),
        border: Border.all(color: OnyxDesignTokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: OnyxDesignTokens.backgroundPrimary.withValues(alpha: 0.42),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: OnyxTypographyTokens.sansFamily,
        color: OnyxDesignTokens.textSecondary,
        fontSize: OnyxTypographyTokens.bodyMd,
        fontWeight: OnyxTypographyTokens.bold,
      ),
    );
  }

  Widget _buildField({
    required Key key,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    bool autofocus = false,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: obscureText,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontFamily: OnyxTypographyTokens.sansFamily,
        color: OnyxDesignTokens.textPrimary,
        fontSize: OnyxTypographyTokens.bodyLg,
        fontWeight: OnyxTypographyTokens.semibold,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: OnyxTypographyTokens.sansFamily,
          color: OnyxDesignTokens.textMuted,
          fontSize: OnyxTypographyTokens.bodyLg,
          fontWeight: OnyxTypographyTokens.medium,
        ),
        filled: true,
        fillColor: OnyxDesignTokens.backgroundSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        prefixIcon: Icon(icon, color: OnyxDesignTokens.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OnyxRadiusTokens.lg),
          borderSide: const BorderSide(color: OnyxDesignTokens.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OnyxRadiusTokens.lg),
          borderSide: const BorderSide(color: OnyxDesignTokens.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OnyxRadiusTokens.lg),
          borderSide: const BorderSide(color: OnyxDesignTokens.cyanInteractive),
        ),
      ),
    );
  }
}
