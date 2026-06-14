import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/big_button.dart';
import '../widgets/pet_view.dart';
import 'parent_gate_screen.dart';
import 'scan_screen.dart';
import 'text_list_screen.dart';

/// 1. 子どもホーム画面。
/// ペット・名前・レベル・経験値・今日の音読・1行モード・ごはん数・連続日数。
class ChildHomeScreen extends StatelessWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pet = app.pet;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Column(
            children: [
              // 上部バー（親画面へのこっそりボタン）
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    const Text('よみたま',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'おうちのひと',
                      icon: const Icon(Icons.settings, color: AppTheme.textDark),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ParentGateScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // ペット名
                      Text(
                        pet.name,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark),
                      ),
                      Text('${pet.stage.label}・レベル${pet.level}',
                          style: const TextStyle(
                              fontSize: 18, color: AppTheme.textDark)),
                      const SizedBox(height: 8),

                      // ペット
                      PetView(stage: pet.stage, size: 220),
                      const SizedBox(height: 12),

                      // 経験値バー
                      _ExpBar(progress: pet.stageProgress, exp: pet.exp),
                      const SizedBox(height: 16),

                      // ステータス（ごはん・連続日数・なかよし）
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatChip(
                              emoji: '🍚',
                              label: 'ごはん',
                              value: '${pet.energy}'),
                          const SizedBox(width: 12),
                          _StatChip(
                              emoji: '🔥',
                              label: 'れんぞく',
                              value: '${pet.streakDays}日'),
                          const SizedBox(width: 12),
                          _StatChip(
                              emoji: '💖',
                              label: 'なかよし',
                              value: '${pet.friendship}'),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 今日の音読ボタン
                      BigButton(
                        label: 'きょうの おんどく',
                        icon: Icons.menu_book_rounded,
                        width: double.infinity,
                        onPressed: () => _startReading(context, singleLine: false),
                      ),
                      const SizedBox(height: 12),

                      // 1行だけモード
                      BigButton(
                        label: '1ぎょうだけ よむ',
                        icon: Icons.short_text_rounded,
                        color: AppTheme.secondary,
                        width: double.infinity,
                        onPressed: () => _startReading(context, singleLine: true),
                      ),
                      const SizedBox(height: 12),

                      // 教科書をスキャン
                      BigButton(
                        label: 'きょうかしょを とる',
                        icon: Icons.camera_alt_rounded,
                        color: AppTheme.accent,
                        width: double.infinity,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanScreen()),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startReading(BuildContext context, {required bool singleLine}) {
    final app = context.read<AppState>();
    if (app.texts.isEmpty) {
      // まだ文章がないときは、やさしくスキャンへ誘導。
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('よむ おはなしを つくろう'),
          content: const Text('きょうかしょや 本を カメラで とってみよう！'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('あとで'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
              },
              child: const Text('カメラを ひらく'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextListScreen(singleLineMode: singleLine),
      ),
    );
  }
}

class _ExpBar extends StatelessWidget {
  final double progress;
  final int exp;
  const _ExpBar({required this.progress, required this.exp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 22,
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
          ),
        ),
        const SizedBox(height: 4),
        Text('けいけんち $exp',
            style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  const _StatChip(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
        ],
      ),
    );
  }
}
