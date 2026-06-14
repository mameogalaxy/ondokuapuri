import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 声の大きさをリアルタイムで見せる音量バー。
/// 「声が聞こえたよ」を視覚的に伝えます（採点ではありません）。
class VolumeBar extends StatelessWidget {
  /// 0.0〜1.0 の音量。
  final double level;

  const VolumeBar({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    const barCount = 12;
    final active = (level.clamp(0.0, 1.0) * barCount).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(barCount, (i) {
            final on = i < active;
            final height = 16.0 + i * 4.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 12,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: on
                    ? Color.lerp(AppTheme.secondary, AppTheme.primary,
                        i / barCount)
                    : Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          level > 0.15 ? 'いい声が きこえてるよ！' : 'こえを きかせてね',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
