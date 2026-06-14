import 'dart:async';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 録音処理コード。
///
/// `record` パッケージで音声を録音し、音量レベル（振幅）を定期取得します。
/// 録音ファイルは端末内（アプリのドキュメントディレクトリ）に保存します。
/// 音声は端末外へ送信しません。
///
/// 初期版では「全文一致の採点」は行いません。代わりに
/// 録音時間・音量レベル・読了ボタン等で音読を肯定的に評価します。
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Timer? _ampTimer;
  final List<double> _volumeSamples = [];

  /// 現在の音量（0.0〜1.0）を流すストリーム。音量バーの表示に使います。
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeController.stream;

  DateTime? _startedAt;
  String? _currentPath;

  bool get isRecording => _startedAt != null;

  /// マイク権限の確認。
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// 録音開始。保存先パスを返します。
  Future<String> start() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('マイクの権限がありません');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'reading_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = '${dir.path}/$fileName';

    _volumeSamples.clear();
    _currentPath = path;
    _startedAt = DateTime.now();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      path: path,
    );

    // 約100msごとに音量を取得し、0.0〜1.0 に正規化して流します。
    _ampTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      try {
        final amp = await _recorder.getAmplitude();
        final normalized = _normalize(amp.current);
        _volumeSamples.add(normalized);
        if (!_volumeController.isClosed) _volumeController.add(normalized);
      } catch (_) {
        // 取得失敗時は無視（録音は継続）。
      }
    });

    return path;
  }

  /// 録音停止。録音結果（時間・平均/最大音量・パス）を返します。
  Future<RecordingResult> stop() async {
    _ampTimer?.cancel();
    _ampTimer = null;

    final path = await _recorder.stop();
    final started = _startedAt ?? DateTime.now();
    final durationSec = DateTime.now().difference(started).inSeconds;

    final avg = _volumeSamples.isEmpty
        ? 0.0
        : _volumeSamples.reduce((a, b) => a + b) / _volumeSamples.length;
    final max =
        _volumeSamples.isEmpty ? 0.0 : _volumeSamples.reduce(math.max);

    _startedAt = null;
    final resultPath = path ?? _currentPath;

    return RecordingResult(
      path: resultPath,
      durationSec: durationSec,
      averageVolume: avg,
      maxVolume: max,
    );
  }

  /// 録音をキャンセルして破棄します。
  Future<void> cancel() async {
    _ampTimer?.cancel();
    _ampTimer = null;
    _startedAt = null;
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  /// dBFS（おおよそ -60〜0）を 0.0〜1.0 に正規化します。
  double _normalize(double db) {
    const minDb = -45.0;
    if (db.isNaN || db.isInfinite) return 0.0;
    final clamped = db.clamp(minDb, 0.0);
    return ((clamped - minDb) / (0 - minDb)).clamp(0.0, 1.0);
  }

  Future<void> dispose() async {
    _ampTimer?.cancel();
    await _volumeController.close();
    await _recorder.dispose();
  }
}

/// 録音結果。
class RecordingResult {
  final String? path;
  final int durationSec;
  final double averageVolume;
  final double maxVolume;

  RecordingResult({
    required this.path,
    required this.durationSec,
    required this.averageVolume,
    required this.maxVolume,
  });
}
