import 'package:flutter/material.dart';

class ChitCard extends StatelessWidget {
  final String groupName;
  final int chitAmount;
  final int currentMonth;
  final int totalMonths;
  final String nextAuctionText;
  final String nextDueText;

  const ChitCard({
    super.key,
    required this.groupName,
    required this.chitAmount,
    required this.currentMonth,
    required this.totalMonths,
    required this.nextAuctionText,
    required this.nextDueText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final progress =
    totalMonths == 0 ? 0.0 : currentMonth / totalMonths;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Group name
            Text(
              groupName,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            // Amount
            Text(
              "₹${_formatAmount(chitAmount)}",
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),

            const SizedBox(height: 12),

            // Progress
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: colors.surfaceVariant,
                      valueColor:
                      AlwaysStoppedAnimation(colors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "$currentMonth / $totalMonths",
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Next auction
            Text(
              "Next Auction: $nextAuctionText",
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 4),

            // Next due
            Text(
              "Next Due: $nextDueText",
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatAmount(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
  }
}
