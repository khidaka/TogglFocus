# TogglFocus

Toggl Track をラップする iPhone アプリ。アクティブなプロジェクトの最新ログだけを一覧してタップ一発でタイマーを再開する、実行特化の薄いラッパー。

- ターゲット: iPhone Air / iOS 26.0+
- 言語: Swift 6 / SwiftUI
- 永続化: SwiftData (App Group コンテナ)
- Live Activity: ActivityKit + Dynamic Island、Stop ボタンは App Intent

## 機能

- アクティブ(非アーカイブ)プロジェクトの最新 time entry を一覧
- 行タップで同じ description で新しい time entry を開始
- 行ごとにローカルノートと作業参照 URL を登録(SwiftData)。タイマー停止時にローカルノートを Toggl の description に反映
- ロック画面 / Dynamic Island に Live Activity 表示。Dynamic Island 内の Stop ボタンでアプリ未起動でも停止可能

レポート / ゴール / グラフは持たない。

## 必要なもの

- macOS 15+ / Xcode 26+
- Homebrew + [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- 無料 Apple ID(個人利用なら可。実機転送は 7 日ごとに再署名が必要)
- iPhone Air 実機(Live Activity / Dynamic Island はシミュレータでも一部確認できるが実機推奨)
- Toggl Track アカウント + API トークン (https://track.toggl.com/profile の最下部)

## セットアップ

```bash
brew install xcodegen
cd TogglFocus
xcodegen generate
open TogglFocus.xcodeproj
```

Xcode で:

1. 左の Project Navigator で `TogglFocus` プロジェクトを選択
2. **Signing & Capabilities** タブで `Team` を自分の Apple ID に設定(`TogglFocus` と `TogglFocusWidget` の両ターゲット)
3. App Group `group.com.hidaka.TogglFocus` が両ターゲットに付いているか確認(`project.yml` で entitlements に書いているので XcodeGen 生成後そのまま入っている想定)
4. iPhone Air を Mac にケーブル接続 → 端末を選択 → Run
5. 初回はトークン未設定のため自動で **設定画面**が開く。Toggl のプロフィールページからコピーしたトークンを貼り付け、「保存して接続テスト」を押す

無料 Apple ID で署名する場合、実機にインストールしてから 7 日で証明書が切れるので、その都度 Xcode から再ビルドする。

## ディレクトリ構成

```
TogglFocus/
├── project.yml                       # XcodeGen 定義
├── README.md
├── TogglFocus/                       # アプリ本体ターゲット
│   ├── TogglFocusApp.swift
│   ├── Info.plist
│   ├── TogglFocus.entitlements
│   ├── Models/                       # API DTO + SwiftData @Model + AppGroup 共有
│   ├── Networking/                   # TogglClient (URLSession + async/await)
│   ├── Stores/                       # @Observable な ProjectStore / TimerStore
│   ├── Views/                        # SwiftUI 画面群
│   ├── Util/
│   ├── Intents/                      # StopRunningEntryIntent (Widget と共有)
│   └── LiveActivity/                 # ActivityAttributes (Widget と共有)
└── TogglFocusWidget/                 # Widget Extension ターゲット
    ├── TogglFocusWidgetBundle.swift
    ├── RunningEntryLiveActivity.swift
    ├── Info.plist
    └── TogglFocusWidget.entitlements
```

`Intents/` と `LiveActivity/` 配下は `project.yml` で **両ターゲットのソース** として登録されており、ActivityAttributes と App Intent の型が両側で同じものとして解決される。

## 動作確認チェックリスト

実装計画 (`/Users/hidaka/.claude/plans/toggl-track-iphone-toggl-track-glimmering-knuth.md`) の「検証方法」をそのまま使う:

1. 設定画面で接続テスト成功
2. アクティブプロジェクトのみ表示、アーカイブ済みは出ない
3. 各行に最新 description / なければ「(履歴なし)」
4. 行タップで Web 側に新規 time entry が立つ
5. 連続タップで自動的に旧エントリ停止 + 新規開始
6. Stop で Web 側でも停止
7. URL/ノート登録 → 行表示 + 🔗 アイコン + Safari ビュー
8. トークン誤入力でクラッシュしない
9. ロック画面 / Dynamic Island に Live Activity が出る
10. Dynamic Island の Stop で停止できる
11. 連続再開で旧 Live Activity が消えて新しいのが立つ
12. ノート編集 → Stop で Toggl description が更新される
13. アプリを開かず Dynamic Island から Stop しても description 更新

## 既知の注意点

- API トークンは初版では App Group 共有 UserDefaults に平文保存。個人利用 + 端末ローカル前提だが、Keychain 移行は将来課題
- `Activity<TogglFocusAttributes>.activities` を `MainActor` から触る箇所があり、Swift 6 strict concurrency で警告が出る可能性。実害が出たら `@preconcurrency` で抑制する
- iCloud 同期はしない。複数端末で URL/ノートを共有したい場合は CloudKit 化が必要
