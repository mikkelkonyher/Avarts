// Flutter imports
import 'package:flutter/material.dart';

// Project imports
import 'package:avarts/pages/register_page.dart';
import 'package:avarts/pages/activity_feed_page.dart';
import 'package:avarts/services/auth_service.dart';

/// Login page where users authenticate with email and password
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Form and input controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Services and state
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final TextEditingController _resetEmailController = TextEditingController();

  /// Handles the login form submission
  /// Validates form, calls API, and navigates to activity feed on success
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final loginResult = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActivityFeedPage(loginResult: loginResult),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: ${error.message}')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handles forgot password functionality
  Future<void> _handleForgotPassword() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: _resetEmailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email address',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_resetEmailController.text.trim()),
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _authService.resetPassword(email: result);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
          ),
        );
        _resetEmailController.clear();
      } on AuthException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: ${error.message}'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App branding badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.surfaceContainerHighest),
                    ),
                    child: Text(
                      'Avarts Membership',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Welcome text
                  Text(
                    'Welcome back, slacker',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to continue your journey of doing absolutely nothing.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login form card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email input field
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'legend@lazystrava.com',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) => value!.isEmpty
                                  ? 'Please enter your email'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Password input field with visibility toggle
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: '••••••••',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) => value!.isEmpty
                                  ? 'Please enter your password'
                                  : null,
                            ),
                            const SizedBox(height: 8),

                            // Forgot password link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _handleForgotPassword,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Login button
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleLogin,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(
                                _isLoading ? 'Logging in...' : 'Log in',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Link to registration page
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => const RegisterPage(),
                                        ),
                                      );
                                    },
                              child: const Text('New here? Create an account'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
