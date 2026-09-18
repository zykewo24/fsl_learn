import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/auth_header.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/widgets/social_button.dart';
import '../controller/auth_controller.dart';
import 'signup_screen.dart';

/// Enhanced sign-in page: branded header, inline validation with helpful
/// error states, a working password-reset flow, and clearer feedback.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  String? _serverError;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);

    await ref.read(authControllerProvider.notifier).signIn(
          email: emailController.text.trim(),
          password: passwordController.text,
        );

    if (!mounted) return;

    final state = ref.read(authControllerProvider);

    state.whenOrNull(
      data: (_) {
        if (!mounted) return;
        context.go(AppRoutes.home);
      },
      error: (e, _) {
        setState(() => _serverError = _friendlyAuthError(e.toString()));
      },
    );
  }

  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('email')) return 'No account found for that email.';
    if (lower.contains('password') || lower.contains('credential')) {
      return 'Incorrect password. Please try again.';
    }
    return raw;
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "Enter your account email and we'll send you a password reset link.",
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              hint: "Email",
              icon: Icons.email_outlined,
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Send Link"),
          ),
        ],
      ),
    );

    final email = controller.text.trim();
    controller.dispose();

    if (confirmed != true || email.isEmpty) return;

    final loading = ref.read(authControllerProvider).isLoading;
    if (loading) return;

    await ref.read(authControllerProvider.notifier).resetPassword(email);

    if (!mounted) return;

    ref.read(authControllerProvider).whenOrNull(
          data: (_) => _showSnack(
            "If an account exists for $email, a reset link has been sent.",
          ),
          error: (e, _) => _showSnack("Unable to send reset link: $e"),
        );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _socialSignIn(String provider) async {
    FocusScope.of(context).unfocus();
    if (ref.read(authControllerProvider).isLoading) return;
    setState(() => _serverError = null);

    final notifier = ref.read(authControllerProvider.notifier);
    if (provider == 'Google') {
      await notifier.signInWithGoogle();
    } else if (provider == 'Facebook') {
      await notifier.signInWithFacebook();
    }

    if (!mounted) return;

    ref.read(authControllerProvider).whenOrNull(
      error: (e, _) {
        if (!mounted) return;
        setState(() => _serverError = _friendlyAuthError(e.toString()));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.topCenter,
                child: AuthHeader(
                  title: "Welcome Back",
                  subtitle: "Sign in to continue learning Filipino Sign Language.",
                ),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: "Email",
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Please enter your email.";
                        }
                        if (!_isValidEmail(value)) {
                          return "Please enter a valid email address.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => loading ? null : _signIn(),
                      decoration: _inputDecoration(
                        label: "Password",
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty)
                              ? "Please enter your password."
                              : null,
                    ),
                    if (_serverError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.danger,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _serverError!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text("Forgot Password?"),
                      ),
                    ),
                    const SizedBox(height: 4),
                    CustomButton(
                      text: "Sign In",
                      isLoading: loading,
                      onPressed: loading ? null : _signIn,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "or continue with",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  SocialButton(
                    text: "Google",
                    icon: Icons.g_mobiledata,
                    onPressed: () => _socialSignIn("Google"),
                  ),
                  const SizedBox(width: 12),
                  SocialButton(
                    text: "Facebook",
                    icon: Icons.facebook,
                    onPressed: () => _socialSignIn("Facebook"),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Students and faculty members may use their institutional email address to access additional learning resources.",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account?", style: TextStyle(color: Colors.grey.shade700)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text("Sign Up"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared decoration so the login fields stay consistent with the existing
/// CustomTextField look, but without referencing custom widgets internally.
InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: label,
    prefixIcon: Icon(icon, color: Colors.grey),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );
}
