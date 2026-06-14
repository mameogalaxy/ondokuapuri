/// 親からのほめスタンプ。
enum StampType {
  great, // すごい！
  nice, // いいね
  fun, // たのしい
  heart; // だいすき

  String get emoji {
    switch (this) {
      case StampType.great:
        return '⭐';
      case StampType.nice:
        return '👍';
      case StampType.fun:
        return '🎵';
      case StampType.heart:
        return '❤️';
    }
  }

  String get label {
    switch (this) {
      case StampType.great:
        return 'すごい！';
      case StampType.nice:
        return 'いいね';
      case StampType.fun:
        return 'たのしいね';
      case StampType.heart:
        return 'だいすき';
    }
  }
}

/// 親が音読セッションに対して送るフィードバック（ほめスタンプ）。
class ParentFeedback {
  final String id;
  final String sessionId;
  final StampType stampType;
  final String? comment;
  final DateTime createdAt;

  ParentFeedback({
    required this.id,
    required this.sessionId,
    required this.stampType,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'stampType': stampType.name,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ParentFeedback.fromJson(Map<String, dynamic> json) => ParentFeedback(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        stampType: StampType.values.firstWhere(
          (s) => s.name == json['stampType'],
          orElse: () => StampType.nice,
        ),
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
