import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_shell.dart';

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
          account.password == password) {
        match = account;
        break;
      }
    }
    if (match == null) {
      setState(() {
        _errorText = 'Use one of the demo accounts below to continue.';
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
      _passwordController.text = account.password;
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
      backgroundColor: const Color(0xFF090D14),
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
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF253246),
                                ),
                                color: const Color(0xFF0E1622),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 34,
                                color: Color(0xFF27C1F3),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'ONYX SECURITY',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFF5F7FB),
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Operations Control Platform',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF7B879A),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Controller Login',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFF3F7FC),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF87171),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                                  backgroundColor: const Color(0xFF1CB8E7),
                                  foregroundColor: const Color(0xFFF8FCFF),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
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
                              style: GoogleFonts.inter(
                                color: const Color(0xFF6F7A8A),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
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
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF202A38),
                                    ),
                                    color: const Color(0xFF0B1119),
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
                                              style: GoogleFonts.robotoMono(
                                                color: const Color(0xFFEAF4FF),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              account.roleLabel,
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF27C1F3),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '/ ${account.password}',
                                              style: GoogleFonts.robotoMono(
                                                color: const Color(0xFF7D8EA5),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        account.accessLabel,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF7D8EA5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
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
                                  foregroundColor: const Color(0xFFF87171),
                                  side: const BorderSide(
                                    color: Color(0xFF7F1D1D),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
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
        color: const Color(0xFF0D131C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E2836)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 30,
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
      style: GoogleFonts.inter(
        color: const Color(0xFFB2BECE),
        fontSize: 14,
        fontWeight: FontWeight.w700,
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
      style: GoogleFonts.inter(
        color: const Color(0xFFF3F7FC),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFF5F6A7B),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF5F6A7B)),
        filled: true,
        fillColor: const Color(0xFF0A1018),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF222D3C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF222D3C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF27C1F3)),
        ),
      ),
    );
  }
}
