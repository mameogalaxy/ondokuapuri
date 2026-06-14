/// ペットの進化段階。
enum PetStage {
  egg, // たまご
  chick, // ひよこ
  child, // こどもペット
  evolved, // 進化ペット
  rare; // レア進化

  String get label {
    switch (this) {
      case PetStage.egg:
        return 'たまご';
      case PetStage.chick:
        return 'ひよこ';
      case PetStage.child:
        return 'こどもペット';
      case PetStage.evolved:
        return '進化ペット';
      case PetStage.rare:
        return 'レア進化';
    }
  }

  /// この段階に進化するために必要な累計経験値。
  int get requiredExp {
    switch (this) {
      case PetStage.egg:
        return 0;
      case PetStage.chick:
        return 50;
      case PetStage.child:
        return 150;
      case PetStage.evolved:
        return 350;
      case PetStage.rare:
        return 700;
    }
  }

  PetStage? get next {
    final i = index;
    if (i + 1 < PetStage.values.length) return PetStage.values[i + 1];
    return null;
  }
}

/// 育てるペット本体。
class Pet {
  final String id;
  String name;
  PetStage stage;

  /// 表示用レベル（経験値から算出）。
  int level;

  /// 累計経験値。
  int exp;

  /// なかよし度（親のほめスタンプで上がる）。
  int friendship;

  /// げんき（ごはん数）。
  int energy;

  /// 最後に音読した日時。
  DateTime? lastReadAt;

  /// 連続で音読した日数。
  int streakDays;

  /// 5日連続で手に入る進化アイテムの数。
  int evolutionItems;

  Pet({
    required this.id,
    required this.name,
    this.stage = PetStage.egg,
    this.level = 1,
    this.exp = 0,
    this.friendship = 0,
    this.energy = 0,
    this.lastReadAt,
    this.streakDays = 0,
    this.evolutionItems = 0,
  });

  factory Pet.initial() => Pet(
        id: 'pet_main',
        name: 'たまちゃん',
        stage: PetStage.egg,
      );

  /// 現在の段階の中での経験値進捗（0.0〜1.0）。次の段階までの割合。
  double get stageProgress {
    final next = stage.next;
    if (next == null) return 1.0;
    final start = stage.requiredExp;
    final end = next.requiredExp;
    if (end <= start) return 1.0;
    return ((exp - start) / (end - start)).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'stage': stage.name,
        'level': level,
        'exp': exp,
        'friendship': friendship,
        'energy': energy,
        'lastReadAt': lastReadAt?.toIso8601String(),
        'streakDays': streakDays,
        'evolutionItems': evolutionItems,
      };

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        name: json['name'] as String,
        stage: PetStage.values.firstWhere(
          (s) => s.name == json['stage'],
          orElse: () => PetStage.egg,
        ),
        level: (json['level'] as num?)?.toInt() ?? 1,
        exp: (json['exp'] as num?)?.toInt() ?? 0,
        friendship: (json['friendship'] as num?)?.toInt() ?? 0,
        energy: (json['energy'] as num?)?.toInt() ?? 0,
        lastReadAt: json['lastReadAt'] != null
            ? DateTime.parse(json['lastReadAt'] as String)
            : null,
        streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
        evolutionItems: (json['evolutionItems'] as num?)?.toInt() ?? 0,
      );
}
