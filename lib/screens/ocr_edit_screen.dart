import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reading_text.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/big_button.dart';
import 'reading_screen.dart';

/// 3. OCR確認・編集画面。
/// 読み取った文章を表示・編集します。OCR 完了時と編集時に自動保存します。
class OcrEditScreen extends StatefulWidget {
  /// OCRで読み取った文章。
  final String recognizedText;
  final String? sourceImagePath;

  /// 既存テキストの編集時はこちらを渡す。
  final ReadingText? existing;

  const OcrEditScreen({
    super.key,
    this.recognizedText = '',
    this.sourceImagePath,
    this.existing,
  });

  @override
  State<OcrEditScreen> createState() => _OcrEditScreenState();
}

class _OcrEditScreenState extends State<OcrEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _bodyController = TextEditingController(
      text: widget.existing?.body ?? widget.recognizedText,
    );
    _titleController.addListener(_scheduleAutoSave);
    _bodyController.addListener(_scheduleAutoSave);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// 入力が落ち着いたら保存します。OCR の初期結果は ScanScreen で保存済みです。
  void _scheduleAutoSave() {
    if (widget.existing == null) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 350), _autoSave);
  }

  void _autoSave() {
    if (!mounted || widget.existing == null) return;
    final text = widget.existing!
      ..title = _titleController.text.trim()
      ..body = _bodyController.text;
    unawaited(context.read<AppState>().updateText(text));
  }

  /// 1文（。!?）または1行ごとに改行を入れ直す。
  void _splitIntoLines() {
    final tmp = ReadingText(
      id: 'tmp',
      title: '',
      body: _bodyController.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final sentences = tmp.splitIntoSentences();
    _bodyController.text = sentences.join('\n');
    setState(() {});
  }

  Future<void> _finish({required bool thenRead}) async {
    final app = context.read<AppState>();
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('よむ ぶんしょうを いれてね')),
      );
      return;
    }

    ReadingText saved;
    if (widget.existing != null) {
      final t = widget.existing!;
      t.title = _titleController.text.trim();
      t.body = body;
      await app.updateText(t);
      saved = t;
    } else {
      saved = await app.createText(
        title: _titleController.text.trim(),
        body: body,
        sourceImagePath: widget.sourceImagePath,
      );
    }

    if (!mounted) return;
    if (thenRead) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingScreen(text: saved),
        ),
      );
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('じどうで ほぞんしたよ！いつでも よめるよ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ぶんしょうを かくにん')),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('タイトル',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 18),
                  decoration: _inputDecoration('れい：ちいちゃんのかげおくり'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('ぶんしょう',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _splitIntoLines,
                      icon: const Icon(Icons.format_line_spacing),
                      label: const Text('1文ずつに わける'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _bodyController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 20, height: 1.6),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'ここに よみとった ぶんしょうが でるよ。\nまちがいは なおせるよ。',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BigButton(
                        label: 'もどる',
                        icon: Icons.arrow_back_rounded,
                        color: AppTheme.secondary,
                        onPressed: () => _finish(thenRead: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BigButton(
                        label: 'よむ！',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => _finish(thenRead: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
