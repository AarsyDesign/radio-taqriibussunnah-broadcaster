import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AudioLevelMeter extends StatelessWidget {
  const AudioLevelMeter({super.key, required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final bars = List.generate(22, (index) {
      final threshold = (index + 1) / 22;
      final active = level >= threshold;
      final color = threshold > 0.82
          ? AppTheme.danger
          : threshold > 0.62
          ? AppTheme.amber
          : AppTheme.leaf;

      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 16 + (index % 5) * 6,
          decoration: BoxDecoration(
            color: active ? color : const Color(0xFFE9E2D3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, color: AppTheme.forest),
                const SizedBox(width: 8),
                Text(
                  'Audio Level',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${(level * 100).round()}%',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars) ...[bar, const SizedBox(width: 4)],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
