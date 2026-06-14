/// 音読する文章を表すモデル。
///
/// 教科書や本を撮影し、OCRで読み取った文章をユーザーが編集して保存します。
/// 本文・画像・録音はすべて端末内に保存し、外部送信はしません。
class ReadingText {
  final String id;
  String title;
  String body;

  /// 撮影した元画像の端末内パス（任意）。
  String? sourceImagePath;

  final DateTime createdAt;
  DateTime updatedAt;

  /// 学年（例: 3）。未設定可。
  int? grade;

  /// 教科（例: こくご）。未設定可。
  String? subject;

  /// 単元名（例: ちいちゃんのかげおくり）。未設定可。
  String? unitName;

  ReadingText({
    required this.id,
    required this.title,
    required this.body,
    this.sourceImagePath,
    required this.createdAt,
    required this.updatedAt,
    this.grade,
    this.subject,
    this.unitName,
  });

  /// 本文を行に分割します（空行は除外）。
  /// 音読画面での「1行だけモード」や、読んだ行数（ごはん計算）に使います。
  List<String> get lines => body
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  /// 文章を1文（。!?で区切る）または1行ごとに分割した結果を返します。
  List<String> splitIntoSentences() {
    final result = <String>[];
    for (final line in lines) {
      final matches = RegExp(r'[^。．！？!?]+[。．！？!?]?').allMatches(line);
      for (final m in matches) {
        final s = m.group(0)?.trim() ?? '';
        if (s.isNotEmpty) result.add(s);
      }
    }
    return result.isEmpty ? lines : result;
  }

  int get charCount => body.replaceAll(RegExp(r'\s'), '').length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'sourceImagePath': sourceImagePath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'grade': grade,
        'subject': subject,
        'unitName': unitName,
      };

  factory ReadingText.fromJson(Map<String, dynamic> json) => ReadingText(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        sourceImagePath: json['sourceImagePath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        grade: json['grade'] as int?,
        subject: json['subject'] as String?,
        unitName: json['unitName'] as String?,
      );
}
