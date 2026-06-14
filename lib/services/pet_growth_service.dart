import '../models/pet.dart';
import '../models/reading_session.dart';
import '../models/reading_text.dart';

/// 1回の音読で得られた成果。結果画面の演出に使います。
class GrowthResult {
  final int earnedExp;
  final int earnedFood; // 獲得ごはん
  final bool gotTreasure; // 宝箱が開いたか（3分以上）
  final bool leveledUp;
  final bool evolved;
  final PetStage? newStage;
  final bool gotEvolutionItem; // 5日連続ボーナス
  final int newStreakDays;

  /// 子どもに見せる「肯定メッセージ」。否定的な言葉は使いません。
  final String message;

  GrowthResult({
    required this.earnedExp,
    required this.earnedFood,
    required this.gotTreasure,
    required this.leveledUp,
    required this.evolved,
    required this.newStage,
    required this.gotEvolutionItem,
    required this.newStreakDays,
    required this.message,
  });
}

/// ペット育成ロジック。
///
/// 育成ルール:
/// - 1行読めたら、ごはん1個
/// - 30秒以上読めたら経験値10
/// - 1分以上読めたら経験値20
/// - 3分以上読めたら宝箱
/// - 親がほめスタンプを押したら、なかよし度アップ
/// - 5日連続で読んだら進化アイテム
/// - 経験値が一定以上でペットが進化
class PetGrowthService {
  /// 経験値からレベルを算出（50expごとに1レベル）。
  static int levelForExp(int exp) => (exp ~/ 50) + 1;

  /// 文字数に対して極端に短すぎないか（やさしい判定）。
  /// 否定はしないが、ごく短い場合は経験値を控えめにします。
  static bool _isExtremelyShort(int durationSec, int charCount) {
    if (charCount <= 0) return false;
    // 1文字あたり最低 約0.08秒を目安。その3割未満なら「極端に短い」とみなす。
    final expectedMin = charCount * 0.08;
    return durationSec < expectedMin * 0.3 && durationSec < 5;
  }

  /// 経験値の基礎計算。
  static int _baseExpForDuration(int durationSec) {
    if (durationSec >= 60) return 20; // 1分以上
    if (durationSec >= 30) return 10; // 30秒以上
    if (durationSec >= 5) return 5; // 少しでも読めたらプラス
    return 2; // 声が出たら必ずプラス（否定しない）
  }

  /// セッション結果をペットに反映し、GrowthResult を返します。
  /// [pet] は破壊的に更新されます。
  static GrowthResult applySession({
    required Pet pet,
    required ReadingSession session,
    required ReadingText text,
    required DateTime now,
  }) {
    final lineCount = text.lines.length;
    final charCount = text.charCount;

    // --- ごはん（1行=1個。最低1個） ---
    final food = lineCount > 0 ? lineCount : 1;

    // --- 経験値 ---
    var exp = _baseExpForDuration(session.durationSec);
    if (_isExtremelyShort(session.durationSec, charCount)) {
      // 否定はしないが、ごく短い時は基礎分のみ（ボーナス無し）。
      exp = 2;
    }

    // --- 宝箱（3分以上） ---
    final gotTreasure = session.durationSec >= 180;
    if (gotTreasure) exp += 15;

    // --- 連続日数 ---
    final newStreak = _updateStreak(pet.lastReadAt, pet.streakDays, now);
    final gotEvolutionItem = newStreak > 0 && newStreak % 5 == 0;

    // --- ペットへ反映 ---
    final beforeLevel = pet.level;
    final beforeStage = pet.stage;

    pet.exp += exp;
    pet.energy += food;
    pet.streakDays = newStreak;
    pet.lastReadAt = now;
    pet.level = levelForExp(pet.exp);
    if (gotEvolutionItem) pet.evolutionItems += 1;

    // 進化判定（経験値が次段階の必要値に達したら進化）。
    final evolved = _maybeEvolve(pet);

    session.earnedExp = exp;
    session.isCompleted = true;

    final leveledUp = pet.level > beforeLevel;

    return GrowthResult(
      earnedExp: exp,
      earnedFood: food,
      gotTreasure: gotTreasure,
      leveledUp: leveledUp,
      evolved: evolved,
      newStage: evolved ? pet.stage : null,
      gotEvolutionItem: gotEvolutionItem,
      newStreakDays: newStreak,
      message: _buildMessage(
        session: session,
        gotTreasure: gotTreasure,
        leveledUp: leveledUp,
        evolved: evolved,
        beforeStage: beforeStage,
        pet: pet,
      ),
    );
  }

  static bool _maybeEvolve(Pet pet) {
    var evolved = false;
    var next = pet.stage.next;
    while (next != null && pet.exp >= next.requiredExp) {
      pet.stage = next;
      evolved = true;
      next = pet.stage.next;
    }
    return evolved;
  }

  /// 連続日数の更新。日付（年月日）で判定します。
  static int _updateStreak(DateTime? lastReadAt, int currentStreak, DateTime now) {
    if (lastReadAt == null) return 1;
    final last = DateTime(lastReadAt.year, lastReadAt.month, lastReadAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(last).inDays;
    if (diff == 0) return currentStreak == 0 ? 1 : currentStreak; // 同日は維持
    if (diff == 1) return currentStreak + 1; // 連続
    return 1; // 途切れたらリセット（ただし今日は読めたので1）
  }

  /// 肯定的なメッセージのみを生成します。
  static String _buildMessage({
    required ReadingSession session,
    required bool gotTreasure,
    required bool leveledUp,
    required bool evolved,
    required PetStage beforeStage,
    required Pet pet,
  }) {
    if (evolved) return '${pet.name}が ${pet.stage.label} に しんかしたよ！';
    if (gotTreasure) return 'たくさん読めたね！宝箱が ひらいたよ✨';
    if (leveledUp) return 'レベルアップ！ペットがよろこんでる🎉';
    if (session.durationSec >= 60) return '今日もしっかり読めたね！';
    if (session.durationSec >= 30) return 'いい声が聞こえたよ！';
    return '声が聞こえたよ。今日も読めたね！';
  }
}
