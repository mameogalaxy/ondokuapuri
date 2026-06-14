/// 1回の音読の記録。
///
/// 録音時間・音量・読了状況をもとにペットの成長量を決めます。
/// ※ 初期版では「全文一致の採点」は行いません。読めたことを肯定します。
class ReadingSession {
  final String id;
  final String textId;

  final DateTime startedAt;
  DateTime? endedAt;

  /// 録音時間（秒）。
  int durationSec;

  /// 平均音量（0.0〜1.0 に正規化した値）。
  double averageVolume;

  /// 最大音量（0.0〜1.0 に正規化した値）。
  double maxVolume;

  /// 録音ファイルの端末内パス。
  String? audioPath;

  /// 「読み終わった」ボタンが押されたか。
  bool isCompleted;

  /// 親が承認（ほめスタンプ）したか。
  bool parentApproved;

  /// このセッションで獲得した経験値。
  int earnedExp;

  ReadingSession({
    required this.id,
    required this.textId,
    required this.startedAt,
    this.endedAt,
    this.durationSec = 0,
    this.averageVolume = 0,
    this.maxVolume = 0,
    this.audioPath,
    this.isCompleted = false,
    this.parentApproved = false,
    this.earnedExp = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'textId': textId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'durationSec': durationSec,
        'averageVolume': averageVolume,
        'maxVolume': maxVolume,
        'audioPath': audioPath,
        'isCompleted': isCompleted,
        'parentApproved': parentApproved,
        'earnedExp': earnedExp,
      };

  factory ReadingSession.fromJson(Map<String, dynamic> json) => ReadingSession(
        id: json['id'] as String,
        textId: json['textId'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: json['endedAt'] != null
            ? DateTime.parse(json['endedAt'] as String)
            : null,
        durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
        averageVolume: (json['averageVolume'] as num?)?.toDouble() ?? 0,
        maxVolume: (json['maxVolume'] as num?)?.toDouble() ?? 0,
        audioPath: json['audioPath'] as String?,
        isCompleted: json['isCompleted'] as bool? ?? false,
        parentApproved: json['parentApproved'] as bool? ?? false,
        earnedExp: (json['earnedExp'] as num?)?.toInt() ?? 0,
      );
}
