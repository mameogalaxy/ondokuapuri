import 'package:flutter_test/flutter_test.dart';
import 'package:yomitama/models/pet.dart';
import 'package:yomitama/models/reading_session.dart';
import 'package:yomitama/models/reading_text.dart';
import 'package:yomitama/services/pet_growth_service.dart';

ReadingText _text(String body) => ReadingText(
      id: 't1',
      title: 'テスト',
      body: body,
      createdAt: DateTime(2026, 6, 14),
      updatedAt: DateTime(2026, 6, 14),
    );

ReadingSession _session(int durationSec) => ReadingSession(
      id: 's1',
      textId: 't1',
      startedAt: DateTime(2026, 6, 14, 9, 0, 0),
      durationSec: durationSec,
    );

void main() {
  group('PetGrowthService', () {
    test('30秒以上で経験値10、行数ぶんのごはん', () {
      final pet = Pet.initial();
      final text = _text('はる が きた\nさくら が さいた');
      final result = PetGrowthService.applySession(
        pet: pet,
        session: _session(40),
        text: text,
        now: DateTime(2026, 6, 14, 9, 1),
      );
      expect(result.earnedExp, 10);
      expect(result.earnedFood, 2); // 2行
      expect(pet.energy, 2);
    });

    test('1分以上で経験値20', () {
      final pet = Pet.initial();
      final result = PetGrowthService.applySession(
        pet: pet,
        session: _session(75),
        text: _text('ながい ぶんしょう'),
        now: DateTime(2026, 6, 14, 9, 2),
      );
      expect(result.earnedExp, 20);
    });

    test('3分以上で宝箱が開く', () {
      final pet = Pet.initial();
      final result = PetGrowthService.applySession(
        pet: pet,
        session: _session(200),
        text: _text('とても ながい ぶんしょう'),
        now: DateTime(2026, 6, 14, 9, 5),
      );
      expect(result.gotTreasure, isTrue);
    });

    test('経験値が貯まると進化する', () {
      final pet = Pet.initial();
      expect(pet.stage, PetStage.egg);
      pet.exp = 45;
      PetGrowthService.applySession(
        pet: pet,
        session: _session(75), // +20 -> 65 >= 50
        text: _text('ぶんしょう'),
        now: DateTime(2026, 6, 14, 9, 6),
      );
      expect(pet.stage, PetStage.chick);
    });

    test('短すぎても否定せず必ずプラスになる', () {
      final pet = Pet.initial();
      final result = PetGrowthService.applySession(
        pet: pet,
        session: _session(1),
        text: _text('とても ながい ぶんしょうを よむ はずだった'),
        now: DateTime(2026, 6, 14, 9, 7),
      );
      expect(result.earnedExp, greaterThan(0));
      expect(result.message, isNotEmpty);
    });

    test('5日連続で進化アイテムを獲得', () {
      final pet = Pet.initial()
        ..streakDays = 4
        ..lastReadAt = DateTime(2026, 6, 13, 9, 0);
      final result = PetGrowthService.applySession(
        pet: pet,
        session: _session(40),
        text: _text('ぶん'),
        now: DateTime(2026, 6, 14, 9, 0),
      );
      expect(result.newStreakDays, 5);
      expect(result.gotEvolutionItem, isTrue);
      expect(pet.evolutionItems, 1);
    });
  });
}
