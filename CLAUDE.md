# TogglFocus

Toggl Track をラップする iPhone アプリ。**履歴ではなく実行に特化した薄いラッパー** として、アクティブプロジェクトの最新ログを一覧してタップ一発でタイマーを再開する用途のもの。レポート / ゴール / 集計機能は意図的に持たない。

公開リポジトリ: https://github.com/khidaka/TogglFocus

## 設計上の重要事項

- **ターゲットは iPhone Air / iOS 26.0+ の単機種**。ユニバーサルレイアウトを過剰に作り込まない。
- **個人利用 + 自前ビルド前提**。App Store 配布は想定しない。Apple Developer 無料枠で 7 日ごと再署名する運用。
- **API トークンは App Group 共有 UserDefaults に平文保存**。Keychain には移していない (個人利用で許容)。
- **iCloud 同期はしない**。ローカルメタ情報 (URL + ノート) は SwiftData で端末ローカルのみ。
- **外部依存ゼロ**。SwiftPM パッケージは追加しない方針。標準 SDK だけで構成。

## ローカルノート ↔ Toggl description の関係

`ProjectMeta.note` (SwiftData) がアプリ内のソース・オブ・トゥルース。タイマー停止時に **PUT /time_entries/{id}** で Toggl 側 description にノートを反映してから **PATCH .../stop** する 2 ステップ。ノート未設定のプロジェクトは反映処理をスキップ(空文字で上書きしない)。Live Activity の Stop ボタン (App Intent) も同じ流れを実行する。

## アーキテクチャ

```
TogglFocus/                        # アプリ本体ターゲット
├── TogglFocusApp.swift            # @main, ModelContainer 注入
├── Models/                        # API DTO + @Model + AppGroup 共有設定
├── Networking/TogglClient.swift   # actor, URLSession + async/await
├── Stores/                        # @Observable + @MainActor
├── Views/                         # SwiftUI 画面
├── Intents/                       # StopRunningEntryIntent (Widget と共有)
└── LiveActivity/                  # ActivityAttributes (Widget と共有)

TogglFocusWidget/                  # Widget Extension ターゲット
└── RunningEntryLiveActivity.swift # ロック画面 + Dynamic Island
```

`Intents/` と `LiveActivity/` 配下、および `Models/` のうち `TogglProject` `TogglTimeEntry` `ProjectMeta` `AppGroup` `SharedModelContainer` は `project.yml` で **両ターゲットのソース** として登録されている。共有 SwiftData (App Group コンテナ) を Widget 側からも開くため。

## ビルド / 実行

```bash
brew install xcodegen
xcodegen generate
open TogglFocus.xcodeproj
```

Xcode で `TogglFocus` / `TogglFocusWidget` 両ターゲットの Signing & Capabilities に Team を設定する必要がある (XcodeGen は Team を埋めない)。スキームは **`TogglFocus`** を選んで Run。`TogglFocusWidget` を直接 Run すると `Failed to show Widget` エラーになる(Live Activity 専用 Extension のため単体実行できない)。

`.xcodeproj` は `.gitignore` 済み。クローンしたら毎回 `xcodegen generate` する。

## 重要な制約 / ハマりどころ

- **`/me/time_entries?since=` は 3ヶ月より古い値で 400**。`ProjectStore` は 60 日前を `since` にしている。
- **Toggl 無料プランは 1 時間あたりの API コール数に上限あり (402 エラー)**。開発中にプル更新を連打すると引っかかる。
- **カスタム URL スキーム (例: `obsidian://`) は `SFSafariViewController` で開けない**。`ActiveProjectsView` で `url.scheme` が http(s) かで分岐し、それ以外は `@Environment(\.openURL)` 経由で外部アプリへ。
- **AppIntent の `static var title` は Swift 6 で concurrency 警告**。`static let` で受ける。
- **Activity 参照を `@MainActor` プロパティに保持すると Sendable 越境警告**。`activityId: String?` だけ保持して `Activity.activities` から都度引き直す。
- **`ISO8601DateFormatter` は非 Sendable**。`Date.ISO8601FormatStyle` (値型 + Sendable) を使う。
- **アプリアイコンは `scripts/generate_icon.swift` で生成**(CoreGraphics)。トーンは「JournalToObsidian」アプリと揃え、黒地 × 白の単一シンボル(円 + ▶)に統一。色アクセントは入れない。

## 計画ファイル

実装計画と検証チェックリスト: `/Users/hidaka/.claude/plans/toggl-track-iphone-toggl-track-glimmering-knuth.md`
