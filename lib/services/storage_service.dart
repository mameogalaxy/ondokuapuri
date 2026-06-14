import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/parent_feedback.dart';
import '../models/pet.dart';
import '../models/reading_session.dart';
import '../models/reading_text.dart';

/// ローカル保存処理。
///
/// すべて端末内（shared_preferences）に JSON で保存します。
/// 録音ファイル・画像ファイルは path_provider のディレクトリに保存し、
/// そのパスのみをここで保持します。外部サーバーには一切送信しません。
class StorageService {
  static const _kPet = 'yomitama_pet';
  static const _kTexts = 'yomitama_texts';
  static const _kSessions = 'yomitama_sessions';
  static const _kFeedbacks = 'yomitama_feedbacks';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ---------------- Pet ----------------
  Future<Pet> loadPet() async {
    final p = await _p;
    final raw = p.getString(_kPet);
    if (raw == null) return Pet.initial();
    try {
      return Pet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Pet.initial();
    }
  }

  Future<void> savePet(Pet pet) async {
    final p = await _p;
    await p.setString(_kPet, jsonEncode(pet.toJson()));
  }

  // ---------------- ReadingText ----------------
  Future<List<ReadingText>> loadTexts() async {
    final p = await _p;
    final raw = p.getStringList(_kTexts) ?? [];
    return raw
        .map((s) => ReadingText.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTexts(List<ReadingText> texts) async {
    final p = await _p;
    await p.setStringList(
      _kTexts,
      texts.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  // ---------------- ReadingSession ----------------
  Future<List<ReadingSession>> loadSessions() async {
    final p = await _p;
    final raw = p.getStringList(_kSessions) ?? [];
    return raw
        .map((s) =>
            ReadingSession.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSessions(List<ReadingSession> sessions) async {
    final p = await _p;
    await p.setStringList(
      _kSessions,
      sessions.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  // ---------------- ParentFeedback ----------------
  Future<List<ParentFeedback>> loadFeedbacks() async {
    final p = await _p;
    final raw = p.getStringList(_kFeedbacks) ?? [];
    return raw
        .map((s) =>
            ParentFeedback.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFeedbacks(List<ParentFeedback> feedbacks) async {
    final p = await _p;
    await p.setStringList(
      _kFeedbacks,
      feedbacks.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }
}
