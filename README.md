# よみたま 📖🐣

**音読するとペットが育つ、小学生向けアプリ（Flutter MVP）**

小3の子どもが嫌がりがちな音読を「勉強」ではなく「ペット育成ゲーム」として
楽しく続けられるようにするアプリです。読み間違いを厳しく採点せず、
まずは「声に出して読めた」ことを肯定し、音読習慣をつくることを目的にしています。

---

## 📱 iPhone / スマホですぐ試す（Web版）

App Store も Apple Developer 登録も Mac も不要です。**iPhoneのSafariで下のURLを開くだけ**で動きます（GitHub Pagesで公開）。

```
https://mameogalaxy.github.io/ondokuapuri/
```

- 撮影 → 日本語OCR（ブラウザ内 Tesseract.js）→ 編集 → 音読録音（MediaRecorder）→ ペット成長 まで動作
- 画像・音声・文章は **端末内（localStorage / IndexedDB）にのみ保存**。外部サーバーには送りません（OCRエンジンのファイルのみCDNから読み込み）
- ホーム画面に「追加」すればアプリのように使えます（PWA）

> 実装は `web-app/`。`.github/workflows/deploy-pages.yml` が push時に自動で Pages へデプロイします。
> 初回のみ GitHub の **Settings → Pages → Build and deployment → Source = GitHub Actions** を有効にしてください。

> ⚠️ ネイティブ版（`lib/` 配下の Flutter コード）は ML Kit を使うモバイル専用です。
> 「リンクから試す」目的では上のWeb版を使ってください。両方をこのリポジトリに同梱しています。

---

## ✨ MVPでできること

1. **教科書スキャン**：カメラで教科書・本を撮影
2. **OCR**：Google ML Kit Text Recognition v2（日本語）で文章を抽出（**結果は必ず編集可能**）
3. **音読**：保存した文章を表示し、録音（音量バー・ペットの応援つき）
4. **ペット育成**：録音時間・音量・読了状況に応じて経験値とごはんが増え、ペットが進化
5. **結果演出**：獲得経験値・ごはん・レベルアップ・宝箱・進化演出
6. **親画面**：録音一覧・再生・読んだ文章の確認・ほめスタンプ送信・スタンプ履歴

### 音声の判定方針（重要）
初期版では **全文一致の採点はしません**。代わりに以下で肯定的に評価します。
- 録音時間 / 音量レベル / 「読み終わった」ボタン / 文章量に対して極端に短すぎないか / 親の承認スタンプ

子どもには否定的な言葉を一切出しません（「間違っています」「点数が低い」等は使わない）。

---

## 🗂 プロジェクト構成

```
lib/
├── main.dart                       # エントリポイント（Provider初期化）
├── theme/app_theme.dart            # やさしい配色・大きめUIテーマ
├── models/
│   ├── reading_text.dart           # ReadingText（文章）
│   ├── reading_session.dart        # ReadingSession（音読の記録）
│   ├── pet.dart                    # Pet（ペット・進化段階）
│   └── parent_feedback.dart        # ParentFeedback（ほめスタンプ）
├── services/
│   ├── ocr_service.dart            # OCR処理（ML Kit 日本語・オンデバイス）
│   ├── audio_recorder_service.dart # 録音処理（record・音量取得）
│   ├── pet_growth_service.dart     # ペット育成ロジック
│   └── storage_service.dart        # ローカル保存（shared_preferences）
├── state/app_state.dart            # アプリ全体の状態（ChangeNotifier）
├── widgets/
│   ├── pet_view.dart               # ペット表示・簡易アニメーション（CustomPainter）
│   ├── big_button.dart             # 大きいボタン
│   └── volume_bar.dart             # 音量バー
└── screens/
    ├── child_home_screen.dart      # 1. 子どもホーム
    ├── scan_screen.dart            # 2. 教科書スキャン
    ├── ocr_edit_screen.dart        # 3. OCR確認・編集
    ├── text_list_screen.dart       # 文章えらび
    ├── reading_screen.dart         # 4. 音読
    ├── result_screen.dart          # 5. 結果
    ├── parent_gate_screen.dart     # 親画面ゲート（かんたん計算）
    └── parent_screen.dart          # 6. 親画面
```

---

## 🚀 実行手順

> このリポジトリには `lib/`・`pubspec.yaml`・主要な権限設定が含まれています。
> Android/iOS のネイティブ雛形（gradle/Xcode プロジェクト等）は容量と環境依存のため
> 含めていません。初回のみ次の手順で雛形を生成してください。

```bash
# 1) Flutter SDK（3.4 以降）を用意
flutter --version

# 2) 不足しているプラットフォーム雛形を生成（lib/ と pubspec.yaml は保持されます）
flutter create . --platforms=android,ios --org com.example.yomitama

# 3) 依存を取得
flutter pub get

# 4) 端末を接続して実行
flutter run
```

### 生成後に必ず再適用する設定

`flutter create` で生成される雛形が、本リポジトリの権限設定を上書きすることがあります。
生成後、以下を確認・再適用してください（このリポジトリの該当ファイルが見本です）。

- **`android/app/src/main/AndroidManifest.xml`**：`RECORD_AUDIO` / `CAMERA` 権限、ML Kit の日本語モデル指定
- **`ios/Runner/Info.plist`**：`NSCameraUsageDescription` / `NSMicrophoneUsageDescription`

### Android の最低SDK
ML Kit と record の都合上、`android/app/build.gradle`（または `build.gradle.kts`）の
`minSdkVersion` を **21 以上** にしてください。

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

### iOS
- `ios/Podfile` で `platform :ios, '13.0'` 以上を指定してください（ML Kit 要件）。
- 実機での録音・カメラ確認を推奨します。

---

## 🔐 必要な権限

| プラットフォーム | 権限 | 用途 |
|---|---|---|
| Android | `RECORD_AUDIO` | 音読の録音 |
| Android | `CAMERA` | 教科書スキャン |
| iOS | `NSMicrophoneUsageDescription` | 音読の録音 |
| iOS | `NSCameraUsageDescription` | 教科書スキャン |

---

## 🧮 育成ルール

- 1行読めたら、ごはん 1個
- 30秒以上読めたら 経験値 +10 / 1分以上で +20 / 3分以上で **宝箱**
- 親がほめスタンプを押すと **なかよし度** アップ
- 5日連続で読むと **進化アイテム**
- 経験値が一定以上で **進化**

進化段階：たまご → ひよこ → こどもペット → 進化ペット → レア進化
（必要経験値：0 / 50 / 150 / 350 / 700）

---

## 🛡 プライバシー

- 録音データ・OCR文章・画像は **すべて端末内に保存**します。
- **外部サーバーに送信しません**（OCR も録音もオンデバイス処理）。
- 教科書本文の共有・公開機能はありません。
- クラウド同期・外部AI送信は初期版では実装していません。

---

## 📦 主な使用パッケージ

`google_mlkit_text_recognition` / `camera` / `record` / `audioplayers` /
`path_provider` / `shared_preferences` / `provider` / `uuid` / `intl`

> ペットのアニメーションは MVP では外部アセット不要の `CustomPainter` で実装しています。
> 後から Lottie / Rive に差し替え可能です。
