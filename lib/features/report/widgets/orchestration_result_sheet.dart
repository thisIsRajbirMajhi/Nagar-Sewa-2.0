// lib/features/report/widgets/orchestration_result_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/orchestration_result.dart';
import 'confidence_badge.dart';

class OrchestrationResultSheet extends StatelessWidget {
  final OrchestrationResult result;
  final VoidCallback onApply;

  const OrchestrationResultSheet({
    super.key,
    required this.result,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.navyPrimary),
              const SizedBox(width: 8),
              Text(
                'AI Analysis Results',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConfidenceBadge(
            tier: result.confidenceTier,
            confidence: result.confidence,
          ),
          const SizedBox(height: 16),
          if (result.visionSummary.isNotEmpty) ...[
            Text(
              'Scene',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(result.visionSummary, style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 12),
          ],
          Text(
            'Description',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(result.description, style: GoogleFonts.inter(fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildChip(result.category, Icons.category),
              _buildChip(result.severity, Icons.priority_high),
              if (result.requiresImmediateAction)
                _buildChip(
                  'Urgent',
                  Icons.warning_rounded,
                  color: AppColors.urgentRed,
                ),
            ],
          ),
          if (result.locationHint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Location Hint',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.locationHint,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (result.secondaryIssues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Additional Issues Detected',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: result.secondaryIssues
                  .map(
                    (issue) => Chip(
                      label: Text(issue, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (result.extractedText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Detected Text',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: result.extractedText
                  .map(
                    (text) => Chip(
                      label: Text(text, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Edit Manually'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, {Color? color}) {
    final chipColor = color ?? AppColors.navyPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}
