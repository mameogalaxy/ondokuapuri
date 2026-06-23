import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/parent_feedback.dart';
import '../models/pet.dart';
import '../models/reading_session.dart';
import '../models/reading_text.dart';
import '../services/pet_growth_service.dart';
import '../services/storage_service.dart';

/// アプリ全体の状態。ペット・文章・セッション・フィードバックを保持し、
/// すべてローカルに永続化します。
class AppState extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  AppState(this._storage);

  Pet _pet = Pet.initial();
  List<ReadingText> _texts = [];
  List<ReadingSession> _sessions = [];
  List<ParentFeedback> _feedbacks = [];
  bool _loaded = false;

  Pet get pet => _pet;
  List<ReadingText> get texts => List.unmodifiable(_texts);
  List<ReadingSession> get sessions => List.unmodifiable(_sessions);
  List<ParentFeedback> get feedbacks => List.unmodifiable(_feedbacks);
  bool get loaded => _loaded;

  /// 今日読んだ回数。
  int get todayReadCount {
    final now = DateTime.now();
    return _sessions.where((s) {
      final d = s.startedAt;
      return s.isCompleted &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).length;
  }

  Future<void> load() async {
    _pet = await _storage.loadPet();
    _texts = await _storage.loadTexts();
    _sessions = await _storage.loadSessions();
    _feedbacks = await _storage.loadFeedbacks();
    _loaded = true;
    notifyListeners();
  }

  // ---------------- ReadingText ----------------
  /// OCR完了時など、文章を端末内に確定保存します。
  ///
  /// 呼び出し元はこの Future を待つことで、画面を閉じても文章が消えない
  /// 状態になってから次の画面へ進めます。
  Future<ReadingText> createText({
    required String title,
    required String body,
    String? sourceImagePath,
    int? grade,
    String? subject,
    String? unitName,
  }) async {
    final now = DateTime.now();
    final text = ReadingText(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'なまえのない おはなし' : title.trim(),
      body: body,
      sourceImagePath: sourceImagePath,
      createdAt: now,
      updatedAt: now,
      grade: grade,
      subject: subject,
      unitName: unitName,
    );
    _texts.insert(0, text);
    await _storage.saveTexts(_texts);
    notifyListeners();
    return text;
  }

  /// 編集内容を端末内へ保存します。OCR編集画面から入力のたびに呼ばれます。
  Future<void> updateText(ReadingText text) async {
    text.updatedAt = DateTime.now();
    final i = _texts.indexWhere((t) => t.id == text.id);
    if (i >= 0) _texts[i] = text;
    await _storage.saveTexts(_texts);
    notifyListeners();
  }

  /// 文章を消す唯一の操作。UI ではゴミ箱の確認後だけ呼び出します。
  Future<void> deleteText(String id) async {
    _texts.removeWhere((t) => t.id == id);
    await _storage.saveTexts(_texts);
    notifyListeners();
  }

  ReadingText? textById(String id) {
    for (final t in _texts) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---------------- ReadingSession ----------------
  /// 新しいセッションを開始（録音開始時）。
  ReadingSession startSession(String textId) {
    return ReadingSession(
      id: _uuid.v4(),
      textId: textId,
      startedAt: DateTime.now(),
    );
  }

  /// セッションを確定し、ペットを成長させて GrowthResult を返します。
  Future<GrowthResult> completeSession({
    required ReadingSession session,
    required ReadingText text,
    required int durationSec,
    required double averageVolume,
    required double maxVolume,
    String? audioPath,
  }) async {
    session.endedAt = DateTime.now();
    session.durationSec = durationSec;
    session.averageVolume = averageVolume;
    session.maxVolume = maxVolume;
    session.audioPath = audioPath;

    final result = PetGrowthService.applySession(
      pet: _pet,
      session: session,
      text: text,
      now: DateTime.now(),
    );

    _sessions.insert(0, session);
    await _storage.saveSessions(_sessions);
    await _storage.savePet(_pet);
    notifyListeners();
    return result;
  }

  // ---------------- ParentFeedback ----------------
  /// 親がほめスタンプを送る。なかよし度がアップします。
  Future<void> addParentFeedback({
    required String sessionId,
    required StampType stampType,
    String? comment,
  }) async {
    final feedback = ParentFeedback(
      id: _uuid.v4(),
      sessionId: sessionId,
      stampType: stampType,
      comment: comment,
      createdAt: DateTime.now(),
    );
    _feedbacks.insert(0, feedback);

    final i = _sessions.indexWhere((s) => s.id == sessionId);
    if (i >= 0) _sessions[i].parentApproved = true;

    _pet.friendship += 1;

    await _storage.saveFeedbacks(_feedbacks);
    await _storage.saveSessions(_sessions);
    await _storage.savePet(_pet);
    notifyListeners();
  }

  List<ParentFeedback> feedbacksForSession(String sessionId) =>
      _feedbacks.where((f) => f.sessionId == sessionId).toList();

  ReadingText? textForSession(ReadingSession session) =>
      textById(session.textId);

  /// ペットの名前を変更（親画面から）。
  Future<void> renamePet(String name) async {
    if (name.trim().isEmpty) return;
    _pet.name = name.trim();
    await _storage.savePet(_pet);
    notifyListeners();
  }
}
