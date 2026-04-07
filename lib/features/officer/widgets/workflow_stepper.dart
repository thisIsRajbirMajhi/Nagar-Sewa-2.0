import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// A visual horizontal workflow stepper showing issue lifecycle.
class WorkflowStepper extends StatelessWidget {
  final String currentStatus;
  final ValueChanged<String>? onStepTap;

  const WorkflowStepper({
    super.key,
    required this.currentStatus,
    this.onStepTap,
  });

  /// Ordered steps in the issue lifecycle.
  static const List<_StepDef> _steps = [
    _StepDef('submitted', 'Submitted', Icons.upload_rounded),
    _StepDef('acknowledged', 'Noted', Icons.visibility_rounded),
    _StepDef('assigned', 'Assigned', Icons.person_add_rounded),
    _StepDef('in_progress', 'Working', Icons.engineering_rounded),
    _StepDef('under_review', 'Review', Icons.rate_review_rounded),
    _StepDef('resolved', 'Resolved', Icons.check_circle_rounded),
    _StepDef('closed', 'Closed', Icons.lock_rounded),
  ];

  int get _currentIndex {
    final idx = _steps.indexWhere((s) => s.key == currentStatus);
    return idx == -1 ? 0 : idx;
  }

  /// Returns the next valid status the officer can advance to, or null.
  String? get _nextValidStatus {
    final idx = _currentIndex;
    if (idx < _steps.length - 1) return _steps[idx + 1].key;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Issue Lifecycle',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stepper
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  // Connector line
                  final stepBefore = i ~/ 2;
                  final isCompleted = stepBefore < _currentIndex;
                  return _buildConnector(isCompleted);
                }
                final stepIndex = i ~/ 2;
                return _buildStep(stepIndex);
              }),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStep(int index) {
    final step = _steps[index];
    final isCompleted = index < _currentIndex;
    final isCurrent = index == _currentIndex;
    final isFuture = index > _currentIndex;
    final isNextValid = step.key == _nextValidStatus;

    Color bgColor;
    Color iconColor;
    Color textColor;
    double scale = 1.0;

    if (isCompleted) {
      bgColor = AppColors.greenAccent;
      iconColor = Colors.white;
      textColor = AppColors.greenAccent;
    } else if (isCurrent) {
      bgColor = AppColors.navyPrimary;
      iconColor = Colors.white;
      textColor = AppColors.navyPrimary;
      scale = 1.15;
    } else {
      bgColor = AppColors.surface;
      iconColor = AppColors.textLight;
      textColor = AppColors.textLight;
    }

    return GestureDetector(
      onTap: isNextValid && onStepTap != null
          ? () => onStepTap!(step.key)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circle icon
          AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 300),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: isNextValid
                    ? Border.all(
                        color: AppColors.navyPrimary.withValues(alpha: 0.4),
                        width: 2,
                      )
                    : isFuture
                    ? Border.all(color: AppColors.border, width: 1)
                    : null,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.navyPrimary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : Icon(step.icon, size: 14, color: iconColor),
            ),
          ),
          const SizedBox(height: 5),
          // Label
          Text(
            step.label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(bool isCompleted) {
    return Container(
      width: 18,
      height: 2,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.greenAccent : AppColors.border,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _StepDef {
  final String key;
  final String label;
  final IconData icon;

  const _StepDef(this.key, this.label, this.icon);
}
