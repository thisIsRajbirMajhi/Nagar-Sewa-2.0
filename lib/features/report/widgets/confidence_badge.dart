// lib/features/report/widgets/confidence_badge.dart
import 'package:flutter/material.dart';
import '../../../models/confidence_tier.dart';

class ConfidenceBadge extends StatelessWidget {
  final ConfidenceTier tier;
  final double confidence;

  const ConfidenceBadge({
    super.key,
    required this.tier,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(tier.color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(tier.color).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tier == ConfidenceTier.veryClear
                ? Icons.check_circle
                : tier == ConfidenceTier.likely
                ? Icons.info_outline
                : tier == ConfidenceTier.uncertain
                ? Icons.warning_amber
                : Icons.error_outline,
            size: 14,
            color: Color(tier.color),
          ),
          const SizedBox(width: 4),
          Text(
            '${tier.label} (${(confidence * 100).toInt()}%)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(tier.color),
            ),
          ),
        ],
      ),
    );
  }
}
