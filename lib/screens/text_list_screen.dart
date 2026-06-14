import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'reading_screen.dart';

/// 保存した文章の一覧から、よむ おはなしを えらぶ画面。
class TextListScreen extends StatelessWidget {
  /// 1行だけモードで読むかどうか。
  final bool singleLineMode;

  const TextListScreen({super.key, this.singleLineMode = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final texts = app.texts;

    return Scaffold(
      appBar: AppBar(
        title: Text(singleLineMode ? '1ぎょうだけ よむ' : 'よむ おはなしを えらぶ'),
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: texts.isEmpty
              ? const Center(
                  child: Text('まだ おはなしが ないよ。\nカメラで つくってね！',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: texts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final t = texts[i];
                    final preview = t.body.replaceAll('\n', ' ');
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReadingScreen(
                              text: t,
                              singleLineMode: singleLineMode,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.menu_book_rounded,
                                  color: AppTheme.primary, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.title,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.play_circle_fill,
                                  color: AppTheme.secondary, size: 36),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
