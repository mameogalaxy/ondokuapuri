import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reading_session.dart';
import '../models/reading_text.dart';
import '../services/audio_recorder_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/big_button.dart';
import '../widgets/pet_view.dart';
import '../widgets/volume_bar.dart';
import 'result_screen.dart';

/// 4. 音読画面。
/// 保存した文章を表示・録音開始/停止・音量バー・ペット応援・読み終わったボタン。
class ReadingScreen extends StatefulWidget {
  final ReadingText text;
  final bool singleLineMode;

  const ReadingScreen({
    super.key,
    required this.text,
    this.singleLineMode = false,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();

  ReadingSession? _session;
  bool _isRecording = false;
  double _volume = 0;
  int _elapsedSec = 0;
  Timer? _timer;
  StreamSubscription<double>? _volumeSub;
  bool _finishing = false;

  /// 1行モード用：今読む行のインデックス。
  int _lineIndex = 0;

  List<String> get _lines => widget.text.lines;

  @override
  void dispose() {
    _timer?.cancel();
    _volumeSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('マイクを つかえるように してね')),
      );
      return;
    }

    final app = context.read<AppState>();
    _session = app.startSession(widget.text.id);

    try {
      await _recorder.start();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ろくおんを はじめられませんでした: $e')),
      );
      return;
    }

    _volumeSub = _recorder.volumeStream.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSec++);
    });

    setState(() {
      _isRecording = true;
      _elapsedSec = 0;
    });
  }

  Future<void> _finishReading() async {
    if (_finishing) return;
    _finishing = true;

    _timer?.cancel();
    await _volumeSub?.cancel();

    final result = await _recorder.stop();
    final session = _session;
    if (session == null || !mounted) return;

    final app = context.read<AppState>();
    final growth = await app.completeSession(
      session: session,
      text: widget.text,
      durationSec: result.durationSec,
      averageVolume: result.averageVolume,
      maxVolume: result.maxVolume,
      audioPath: result.path,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: growth,
          durationSec: result.durationSec,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.read<AppState>().pet;
    final lines = _lines;
    final showLines = widget.singleLineMode && lines.isNotEmpty
        ? [lines[_lineIndex.clamp(0, lines.length - 1)]]
        : lines;

    return Scaffold(
      appBar: AppBar(title: Text(widget.text.title)),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Column(
            children: [
              // 応援するペット（小さめ）
              SizedBox(
                height: 130,
                child: Center(
                  child: PetView(
                    stage: pet.stage,
                    size: 120,
                    mood: _isRecording ? PetMood.reading : PetMood.idle,
                  ),
                ),
              ),
              if (_isRecording)
                const Text('ペットが おうえんしてるよ！',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),

              // 文章
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      showLines.join('\n'),
                      style: const TextStyle(fontSize: 26, height: 1.9),
                    ),
                  ),
                ),
              ),

              if (widget.singleLineMode && lines.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _lineIndex > 0
                            ? () => setState(() => _lineIndex--)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('まえ'),
                      ),
                      Text('${_lineIndex + 1} / ${lines.length} 行'),
                      TextButton.icon(
                        onPressed: _lineIndex < lines.length - 1
                            ? () => setState(() => _lineIndex++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('つぎ'),
                      ),
                    ],
                  ),
                ),

              // 音量バー・タイマー・操作
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    if (_isRecording) ...[
                      VolumeBar(level: _volume),
                      const SizedBox(height: 8),
                      Text(_formatTime(_elapsedSec),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      BigButton(
                        label: 'よみ おわった！',
                        icon: Icons.check_circle,
                        width: double.infinity,
                        color: AppTheme.primary,
                        onPressed: _finishReading,
                      ),
                    ] else
                      BigButton(
                        label: 'ろくおん スタート',
                        icon: Icons.mic,
                        width: double.infinity,
                        color: AppTheme.secondary,
                        onPressed: _startRecording,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
