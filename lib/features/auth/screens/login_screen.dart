import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/error_messages.dart';
import '../../../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await SupabaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if email is confirmed
      if (response.user != null &&
          response.user!.emailConfirmedAt == null) {
        if (mounted) {
          _showEmailNotConfirmedDialog(_emailController.text.trim());
        }
        return;
      }

      if (mounted) context.go('/dashboard');
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorMessages.isNetworkError(e)
              ? ErrorMessages.friendly(e)
              : _getAuthErrorMessage(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorMessages.friendly(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getAuthErrorMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Invalid email or password. Please check your credentials or reset your password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Your email hasn\'t been confirmed yet. Please check your inbox.';
    }
    if (msg.contains('too many requests') ||
        msg.contains('rate limit')) {
      return 'Too many login attempts. Please try again later.';
    }
    if (msg.contains('user not found')) {
      return 'No account found with this email. Please register first.';
    }
    return 'Login failed: ${e.message}';
  }

  bool get _isNetworkError =>
      _errorMessage != null &&
      _errorMessage!.toLowerCase().contains('no internet');

  Widget _buildErrorBanner() {
    final isNetwork = _isNetworkError;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isNetwork
            ? const Color(0xFFFFF3E0)
            : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNetwork
              ? const Color(0xFFFFB74D)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline,
                size: 20,
                color: isNetwork
                    ? const Color(0xFFE65100)
                    : AppColors.error.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNetwork ? 'No Connection' : 'Login Failed',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isNetwork
                            ? const Color(0xFFE65100)
                            : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isNetwork
                            ? const Color(0xFFBF360C)
                            : AppColors.error.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isNetwork && _errorMessage!.contains('reset'))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GestureDetector(
                onTap: () => context.push('/forgot-password'),
                child: Text(
                  'Reset Password →',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navyPrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .shake(
          hz: isNetwork ? 1 : 2,
          offset: const Offset(4, 0),
          duration: 400.ms,
        );
  }

  void _showEmailNotConfirmedDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EmailConfirmationDialog(email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 80),
                // Logo
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Nagar ',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyPrimary,
                        ),
                      ),
                      TextSpan(
                        text: 'Sewa',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 8),
                Text(
                  'Login Now',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.greenAccent,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 48),

                // Error banner
                if (_errorMessage != null)
                  _buildErrorBanner(),

                // Email field
                AppTextField(
                  label: 'Email',
                  hintText: 'Enter your email',
                  controller: _emailController,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                const SizedBox(height: 20),

                // Password field
                AppTextField(
                  label: 'Password',
                  hintText: 'Enter password',
                  controller: _passwordController,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return null;
                  },
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textLight,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                const SizedBox(height: 12),

                // Forgot password link (aligned right)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 24),

                // Sign In button
                AppButton(
                  text: 'Sign In',
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                const SizedBox(height: 24),

                // Register link
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: Text.rich(
                    TextSpan(
                      text: 'Don\'t have an account? ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Register',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.greenAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal dialog shown when a user's email is not yet confirmed
class _EmailConfirmationDialog extends StatefulWidget {
  final String email;
  const _EmailConfirmationDialog({required this.email});

  @override
  State<_EmailConfirmationDialog> createState() =>
      _EmailConfirmationDialogState();
}

class _EmailConfirmationDialogState extends State<_EmailConfirmationDialog> {
  bool _isResending = false;
  bool _sent = false;

  Future<void> _resendConfirmation() async {
    setState(() => _isResending = true);
    try {
      await SupabaseService.resendConfirmationEmail(widget.email);
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.friendly(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.mark_email_unread_rounded,
                size: 32,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Email Not Confirmed',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navyPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please confirm your email address before logging in. Check your inbox at:',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.email,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyPrimary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_sent)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Confirmation email sent!',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.greenDark,
                      ),
                    ),
                  ],
                ),
              )
            else
              AppButton(
                text: 'Resend Confirmation Email',
                onPressed: _resendConfirmation,
                isLoading: _isResending,
                backgroundColor: AppColors.greenAccent,
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Sign out the unconfirmed session
                SupabaseService.signOut();
              },
              child: Text(
                'OK, I\'ll check my email',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
