import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/auth_header.dart';
import '../../../core/widgets/custom_button.dart';
import '../controller/auth_controller.dart';

/// Shown when the user taps the password-reset link from the Supabase email.
///
/// The Recovery session is established automatically by `supabase_flutter`
/// when the app is opened with the reset deep link; this screen simply lets the
/// user choose a new password and applies it via [AuthService.updatePassword].
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool _submitting = false;
  String? _serverError;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  String? _strength(String v) {
    var score = 0;
    if (v.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) score++;
    return score >= 4 ? "Strong" : (score >= 2 ? "Okay" : "Weak");
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _serverError = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .updatePassword(newPassword: passwordController.text);

      if (!mounted) return;

      // Sign out of the recovery session and go back to the login screen so the
      // user signs in with the newly chosen password.
      await ref.read(authServiceProvider).signOut();
      AppRouter.recoveryPending = false;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Password Updated"),
          content: const Text(
            "Your password has been changed. Please sign in with your new password.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      ).then((_) {
        if (!mounted) return;
        AppRouter.router.go(AppRoutes.login);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverError =
            "Unable to update your password. The reset link may be expired — "
            "request a new one from the sign-in screen. ($error)";
      });
    }
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
    final strength = _strength(passwordController.text);

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
                  title: "Reset Password",
                  subtitle:
                      "Choose a new password for your account.",
                ),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration(
                        label: "New Password",
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                              () => obscurePassword = !obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter a new password.";
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
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: _decoration(
                        label: "Confirm Password",
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                              () => obscureConfirm = !obscureConfirm),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 20),
                    CustomButton(
                      text: "Update Password",
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        AppRouter.recoveryPending = false;
                        AppRouter.router.go(AppRoutes.login);
                      },
                      child: const Text("Cancel"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
