import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR処理コード。
///
/// Google ML Kit Text Recognition v2 を使い、日本語の教科書・本の写真から
/// 文章を抽出します。処理はすべて端末内（オンデバイス）で完結し、
/// 画像や結果を外部サーバーに送信することはありません。
class OcrService {
  // 日本語スクリプト用の認識器を使用します。
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.japanese);

  /// 画像ファイルパスから文章を抽出して返します。
  /// 改行・段落をできるだけ自然に整形します。OCR結果は必ず編集可能です。
  Future<String> recognizeFromFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText result = await _recognizer.processImage(inputImage);

    final buffer = StringBuffer();
    for (final block in result.blocks) {
      for (final line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln(); // 段落の区切り
    }
    return _cleanup(buffer.toString());
  }

  /// 余分な空白・空行を整理します（誤認識の完全修正はしません。編集で直せます）。
  String _cleanup(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .toList();

    final result = <String>[];
    var prevEmpty = false;
    for (final l in lines) {
      final empty = l.isEmpty;
      if (empty && prevEmpty) continue; // 連続する空行は1つに
      result.add(l);
      prevEmpty = empty;
    }
    return result.join('\n').trim();
  }

  /// 認識器を破棄します（画面破棄時に呼びます）。
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
