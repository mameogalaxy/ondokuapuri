import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/pet_growth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/big_button.dart';
import '../widgets/pet_view.dart';

/// 5. 結果画面。
/// 音読時間・獲得経験値・獲得ごはん・ペットの反応・レベルアップ演出・宝箱演出。
///
/// 子どもに否定的な言葉は出しません。必ず肯定して終わります。
class ResultScreen extends StatefulWidget {
  final GrowthResult result;
  final int durationSec;

  const ResultScreen({
    super.key,
    required this.result,
    required this.durationSec,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final pet = context.read<AppState>().pet;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                ScaleTransition(
                  scale: CurvedAnimation(
                      parent: _popController, curve: Curves.elasticOut),
                  child: const Text('よく よめたね！🎉',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                ),
                const SizedBox(height: 8),

                // よろこぶペット
                PetView(stage: pet.stage, size: 200, mood: PetMood.happy),
                const SizedBox(height: 8),

                // 肯定メッセージ
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),

                // 結果カード
                _resultCard('⏱️', 'おんどく じかん', _formatTime(widget.durationSec)),
                const SizedBox(height: 10),
                _resultCard('⭐', 'けいけんち', '+${r.earnedExp}'),
                const SizedBox(height: 10),
                _resultCard('🍚', 'ごはん', '+${r.earnedFood}'),

                // 演出（条件つき）
                if (r.leveledUp) ...[
                  const SizedBox(height: 16),
                  _banner('🎊 レベルアップ！ 🎊', AppTheme.accent),
                ],
                if (r.evolved && r.newStage != null) ...[
                  const SizedBox(height: 16),
                  _banner('✨ ${r.newStage!.label} に しんか！ ✨',
                      AppTheme.secondary),
                ],
                if (r.gotTreasure) ...[
                  const SizedBox(height: 16),
                  _treasureBanner(),
                ],
                if (r.gotEvolutionItem) ...[
                  const SizedBox(height: 16),
                  _banner('🎁 5日れんぞく！しんかアイテム ゲット！',
                      AppTheme.primary),
                ],

                const SizedBox(height: 12),
                Text('れんぞく ${r.newStreakDays}日め！',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),

                const SizedBox(height: 24),
                BigButton(
                  label: 'おうちに もどる',
                  icon: Icons.home_rounded,
                  width: double.infinity,
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                ),
                const SizedBox(height: 8),
                const Text('きょうは ここまででも OK。また こえを きかせてね！',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultCard(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 18)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _banner(String text, Color color) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _popController, curve: Curves.elasticOut),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }

  Widget _treasureBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD23F), Color(0xFFFF8A3D)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Text('🎁', style: TextStyle(fontSize: 48)),
          SizedBox(height: 8),
          Text('たからばこが ひらいたよ！',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
