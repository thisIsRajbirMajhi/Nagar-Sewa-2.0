import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../utils/validators.dart';

class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  static const List<Color> _strengthColors = [
    Color(0xFFE53935), // Weak - red
    Color(0xFFFF9800), // Fair - orange
    Color(0xFFFFC107), // Good - amber
    Color(0xFF8BC34A), // Strong - light green
  ];

  @override
  Widget build(BuildContext context) {
    final score = Validators.passwordStrength(password);
    final label = Validators.passwordStrengthLabel(score);

    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            final isActive = index < score;
            final color = isActive
                ? _strengthColors[score - 1]
                : AppColors.border;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 4,
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Row(
            key: ValueKey(score),
            children: [
              if (score > 0) ...[
                Icon(
                  score <= 1
                      ? Icons.warning_amber_rounded
                      : score <= 2
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                  size: 14,
                  color: _strengthColors[score - 1],
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: score > 0
                      ? _strengthColors[score - 1]
                      : AppColors.textLight,
                ),
              ),
              const Spacer(),
              if (password.isNotEmpty)
                Text(
                  _getHint(password),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _getHint(String value) {
    if (value.length < 8) return 'Min 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add uppercase';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add lowercase';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Add a number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]~`/\\]').hasMatch(value)) {
      return 'Add special char';
    }
    if (value.length < 12) return 'Longer is stronger';
    return '';
  }
}
