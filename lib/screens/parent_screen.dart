import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/parent_feedback.dart';
import '../models/reading_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// 6. 親画面。
/// 録音一覧・録音再生・読んだ文章・ほめスタンプ送信・スタンプ履歴。
class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingPath;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String? path) async {
    if (path == null) return;
    if (_playingPath == path) {
      await _player.stop();
      setState(() => _playingPath = null);
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    setState(() => _playingPath = path);
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = app.sessions;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('おうちのひと がめん'),
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            tabs: [
              Tab(text: 'おんどく きろく'),
              Tab(text: 'スタンプ りれき'),
            ],
          ),
        ),
        body: Container(
          decoration: AppTheme.backgroundGradient,
          child: SafeArea(
            child: TabBarView(
              children: [
                _buildSessionList(app, sessions),
                _buildStampHistory(app),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionList(AppState app, List<ReadingSession> sessions) {
    if (sessions.isEmpty) {
      return const Center(
          child: Text('まだ 音読の記録が ありません',
              style: TextStyle(fontSize: 16)));
    }
    final df = DateFormat('M/d HH:mm');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = sessions[i];
        final text = app.textForSession(s);
        final feedbacks = app.feedbacksForSession(s.id);
        final isPlaying = _playingPath == s.audioPath;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(text?.title ?? '（削除された文章）',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Text(df.format(s.startedAt),
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  _meta('⏱️ ${_fmt(s.durationSec)}'),
                  _meta('⭐ +${s.earnedExp}'),
                  _meta('🔊 ${(s.averageVolume * 100).round()}%'),
                  if (s.parentApproved) _meta('💖 ほめた'),
                ],
              ),
              if (text != null) ...[
                const SizedBox(height: 8),
                Text(
                  text.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (s.audioPath != null && File(s.audioPath!).existsSync())
                    OutlinedButton.icon(
                      onPressed: () => _togglePlay(s.audioPath),
                      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(isPlaying ? 'ていし' : 'さいせい'),
                    )
                  else
                    const Text('（録音ファイルなし）',
                        style: TextStyle(color: Colors.black45)),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onPressed: () => _showStampPicker(context, app, s.id),
                    icon: const Icon(Icons.favorite, size: 20),
                    label: const Text('ほめスタンプ'),
                  ),
                ],
              ),
              if (feedbacks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: feedbacks
                      .map((f) => Chip(
                            label: Text('${f.stampType.emoji} ${f.stampType.label}'),
                            backgroundColor: AppTheme.bgBottom,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStampHistory(AppState app) {
    final feedbacks = app.feedbacks;
    if (feedbacks.isEmpty) {
      return const Center(
          child: Text('まだ スタンプは ありません',
              style: TextStyle(fontSize: 16)));
    }
    final df = DateFormat('M/d HH:mm');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: feedbacks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final f = feedbacks[i];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(f.stampType.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.stampType.label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    if (f.comment != null && f.comment!.isNotEmpty)
                      Text(f.comment!,
                          style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              Text(df.format(f.createdAt),
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
        );
      },
    );
  }

  void _showStampPicker(BuildContext context, AppState app, String sessionId) {
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        StampType selected = StampType.great;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ほめスタンプを おくろう',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    children: StampType.values.map((st) {
                      final on = st == selected;
                      return ChoiceChip(
                        label: Text('${st.emoji} ${st.label}',
                            style: const TextStyle(fontSize: 16)),
                        selected: on,
                        selectedColor: AppTheme.accent,
                        onSelected: (_) => setSheet(() => selected = st),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: 'ひとこと（れい：いいこえだったね！）',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        app.addParentFeedback(
                          sessionId: sessionId,
                          stampType: selected,
                          comment: commentController.text.trim(),
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('スタンプを おくったよ！なかよし度アップ💖')),
                        );
                      },
                      child: const Text('おくる'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _meta(String text) =>
      Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87));

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
