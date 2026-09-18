import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/auth_header.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/social_button.dart';
import '../controller/auth_controller.dart';

/// Enhanced account-creation page: branded header, inline validation
/// (email format, password strength, matching confirmation) and a clear
/// success flow.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool acceptTerms = false;
  String? _serverError;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  String? _passStrength(String value) {
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;

    if (score >= 4) return "Strong";
    if (score >= 2) return "Okay";
    return "Weak";
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!acceptTerms) {
      _show("Please accept the Terms & Conditions to continue.");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);

    await ref.read(authControllerProvider.notifier).signUp(
          fullName: fullNameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
        );

    if (!mounted) return;

    ref.read(authControllerProvider).whenOrNull(
      data: (_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Account Created"),
            content: const Text(
              "Your account has been created successfully. You may now sign in. "
              "If email confirmation is enabled in Supabase, verify your email first.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      },
      error: (e, _) {
        setState(() => _serverError = _friendlyAuthError(e.toString()));
      },
    );
  }

  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') || lower.contains('exists')) {
      return "An account with that email already exists. Try signing in.";
    }
    if (lower.contains('password')) {
      return "That password doesn't meet the requirements. Use at least 8 characters.";
    }
    return raw;
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
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

  InputDecoration _decoration({
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

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    final strength = _passStrength(passwordController.text);

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
                  title: "Join FSL Learn",
                  subtitle: "Create an account to start learning Filipino Sign Language.",
                ),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: fullNameController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        label: "Full Name",
                        icon: Icons.person_outline,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? "Please enter your full name."
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
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
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration(
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please create a password.";
                        }
                        if (value.length < 8) {
                          return "Use at least 8 characters.";
                        }
                        return null;
                      },
                    ),
                    if (passwordController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(
                          children: [
                            Icon(
                              strength == "Strong"
                                  ? Icons.check_circle
                                  : strength == "Okay"
                                      ? Icons.info_outline
                                      : Icons.warning_amber_rounded,
                              size: 16,
                              color: strength == "Strong"
                                  ? AppColors.success
                                  : strength == "Okay"
                                      ? Colors.amber.shade700
                                      : Colors.red.shade400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Password strength: $strength",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      decoration: _decoration(
                        label: "Confirm Password",
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                              () => obscureConfirmPassword = !obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please confirm your password.";
                        }
                        if (value != passwordController.text) {
                          return "Passwords do not match.";
                        }
                        return null;
                      },
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: acceptTerms,
                          onChanged: (v) {
                            setState(() => acceptTerms = v ?? false);
                          },
                        ),
                        const Expanded(
                          child: Text("I agree to the Terms & Conditions"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: "Create Account",
                      isLoading: loading,
                      onPressed: loading ? null : _signUp,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "or sign up with",
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account?",
                      style: TextStyle(color: Colors.grey.shade700)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Sign In"),
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
