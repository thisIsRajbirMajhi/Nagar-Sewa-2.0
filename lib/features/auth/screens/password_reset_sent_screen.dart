import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../services/supabase_service.dart';

class PasswordResetSentScreen extends StatefulWidget {
  final String? email;
  const PasswordResetSentScreen({super.key, this.email});

  @override
  State<PasswordResetSentScreen> createState() =>
      _PasswordResetSentScreenState();
}

class _PasswordResetSentScreenState extends State<PasswordResetSentScreen> {
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _isResending = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 0) {
        timer.cancel();
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0 || widget.email == null) return;
    setState(() => _isResending = true);
    try {
      await SupabaseService.resetPassword(widget.email!);
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reset link sent again!'),
            backgroundColor: AppColors.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Animated email icon
              Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.mark_email_read_rounded,
                      size: 50,
                      color: AppColors.greenAccent,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  )
                  .then()
                  .shimmer(
                    delay: 500.ms,
                    duration: 1500.ms,
                    color: AppColors.greenAccent.withValues(alpha: 0.3),
                  ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Check Your Email',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyPrimary,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 16),

              // Description
              Text(
                widget.email != null
                    ? 'We\'ve sent a password reset link to\n${widget.email}'
                    : 'We\'ve sent a password reset link to your email.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 12),

              // Tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Check your spam folder if you don\'t see the email in your inbox.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms),

              const Spacer(),

              // Resend button
              TextButton(
                onPressed: _cooldownSeconds > 0 ? null : _handleResend,
                child: _isResending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _cooldownSeconds > 0
                            ? 'Resend in ${_cooldownSeconds}s'
                            : 'Didn\'t receive it? Resend',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _cooldownSeconds > 0
                              ? AppColors.textLight
                              : AppColors.greenAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 12),

              // Back to login
              AppButton(
                text: 'Back to Login',
                onPressed: () => context.go('/login'),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
