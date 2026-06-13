<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-swiftui.png">
  <img alt="WiFi Lens — macOS Wi-Fi spectrum analyzer" src="assets/screenshot-swiftui.png" width="800">
</picture>

# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Build%20&%20Release/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Build+%26+Release%22)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)

**Wi-Fi ネットワークを分析・最適化するためのネイティブ macOS ツール。**

---

## WiFi Lens とは？

WiFi Lens は、SwiftUI、CoreWLAN、CoreBluetooth の 3 つの macOS ネイティブフレームワークだけで構築された無料オープンソースの Wi-Fi および Bluetooth アナライザです。周囲のすべての無線ネットワークと BLE デバイスのリアルタイムな可視化マップを提供し、接続問題を診断し、最も混雑していないチャンネルを選び、アクセスポイント間のローミング動作を検証できます。

Web ベースのスキャナやクロスプラットフォームの Electron アプリとは異なり、WiFi Lens はゼロオーバーヘッドで動作し、プライバシーを尊重し、Mac に完璧に馴染みます。

**典型的なユースケース：**
- 🏠 **ホームネットワークチューニング** — 隣人がどのチャンネルを飽和させているかを見つけ、ルータをより静かなチャンネルに移します。
- 🏢 **オフィス Wi-Fi オーディット** — 3 つのバンド（2.4、5、6 GHz）すべてをスキャンして、デッドゾーンや設定ミスのある AP を特定します。
- 🚶 **ローミング検証** — ビル内を歩きながらすべての AP ハンドオフを記録し、タイムラインチャートでシームレスな遷移を検証します。
- 🎧 **BLE デバイストラブルシューティング** — Bluetooth パーフェラルの RSSI トレンドを追跡し、範囲または干渉の問題を特定します。

---

## 機能

| カテゴリ | 機能 |
|----------|-----------|
| 📡 **Wi-Fi スキャン** | 2.4、5、6 GHz バンド全体でのリアルタイムスキャン、ネットワークごとの信号強度を表示 |
| 📊 **スペクトルビュー** | チャンネル占有を一目で示すガウスベル曲線チャート |
| 🎯 **チャンネル品質** | 混雑スコアと地域ベースの推奨、あなたの規制ドメインに調整済み |
| 🔍 **ネットワーク詳細** | PHY 世代、チャンネル幅、802.11k/r/v ローミング、WPA3、隠し SSID |
| 📶 **接続情報** | IP、ゲートウェイ、DNS、MAC、チャンネル、Tx レート、セキュリティサマリー |
| 📈 **トレンドチャート** | 設定可能なスキャン間隔でネットワークごとの信号履歴を時間経過とともに表示 |
| 🔄 **ローミングテスト** | タイムラインチャート、範囲セレクタ、セッション保存/読み込み機能付き AP 遷移モニタリング |
| 🗺️ **チャンネルヒートマップ** | バンドごとの占有ヒートマップですぐに混雑パターンを特定 |
| 🎧 **BLE スキャナ** | Bluetooth LE デバイス発見、RSSI 分析、トレンドチャート、デバイス追跡 |
| 🎨 **スマートカラーリング** | SSID ベースの決定論的な色割り当て — 同じネットワークは常に同じ色 |
| 🔒 **プライバシーファースト** | テレメトリなし、分析なし、データ収集なし — すべてのデータをあなたの Mac 上に保持 |
| 🌐 **MCP サーバー** | 外部ツール連携用の内蔵 HTTP API（`127.0.0.1:19840`） |
| 🔄 **自動アップデート** | Sparkle 自動更新サポートで常に最新バージョンを維持 |
| 📤 **エクスポート** | バンドごとのチャートを PNG 画像または CSV データとして保存 |
| 🌍 **ローカライズ** | 英語、日本語、簡体字中国語の完全サポート |

---

## WiFi Lens が異なる理由

**ネイティブパフォーマンス、ウェブラッパーではない。** CoreWLAN は Wi-Fi ハードウェアと直接通信 — ミドルウェアなし、JavaScript ブリッジなし、無駄な CPU サイクルなし。最新の Apple Silicon での数百ネットワークのスキャンは楽々です。

**組み込みの規制インテリジェンス。** 多くのツールは生のチャンネル番号を表示して終わりにしますが、WiFi Lens はシステムロケール、ハードウェア機能、近隣 AP の国コードからあなたの規制ドメインを推測し、実際に使用できるチャンネルを推奨 — DFS、屋内専用、6 GHz AFC ルールを尊重します。

**すべてが連携。** テーブルのネットワークをクリックするとすべてのチャートでハイライト表示されます。ベル曲線をホバーすると SSID がポップアップします。1 つのバンドを凍結しながら他は継続スキャン。コックピットのように設計されています。

**パワーユーザー向けスペース。** PNG/CSV エクスポート、セッション保存/読み込み付きローミングテストの実行、組み込み MCP HTTP サーバーで自分のツールと連携 — 隠れた有料壁なし。

---

## ダウンロード

[![最新リリースをダウンロード](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![Mac App Store でダウンロード](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/id6776590746)

macOS 14 (Sonoma) 以降が必要。Intel および Apple Silicon Mac の両方で動作します。

> [!IMPORTANT]
> macOS 14 以上では、Wi-Fi SSID を読み取るために**位置情報サービス**を有効にする必要があります。
> **システム設定 → プライバシーとセキュリティ → 位置情報サービス** に移動し、プロンプトが表示されたら WiFi Lens を有効にします。

### Gatekeeper の回避策

このアプリは完全に署名され、Apple によって公証されています。

- アプリを**右クリック** → **開く** → ダイアログで確認；または
- ターミナルで実行：
  ```sh
  xattr -d com.apple.quarantine /Applications/WiFi\ Lens.app
  ```

---

## プライバシー

WiFi Lens は**何も収集しません**。使用状況分析、クラッシュテレメトリ、外部サーバーへのネットワークトラフィックなし。

- **位置情報サービス** — macOS が Wi-Fi SSID 名を公開するために必要です。WiFi Lens が GPS 位置を読み取ることは決してありません。
- **地域検出** — システムロケール、ハードウェア報告のチャンネルリスト、近隣 AP の国コードを使用。完全にデバイス上で実行。
- **MCP サーバー** — `127.0.0.1` にのみバインド。明示的に他の場所にルーティングしない限り、スキャンデータはあなたのマシンから出ません。

---

## 開発

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens/WiFiLens

# ビルド
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# テスト実行
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' test

# Xcode で開く
xed WiFiLens.xcodeproj
```

製品名は `WiFi Lens.app`（スペース付き）。

### Website

ランディングページは Vite + Tailwind CSS で構築され、`_site/` に出力されます。

```sh
cd wifi-lens          # repo root
npm ci
npm run dev           # dev server at localhost:5173/wifi-lens/
npm run build         # production build
npm run preview       # preview production build
```

アーキテクチャ、テスト、ロードマップのドキュメントは [docs/](docs/) にあります。

---

## 貢献

バグレポートと機能アイデアを歓迎します — [issue](https://github.com/SHIINASAMA/wifi-lens/issues) を開くか [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions) を開始してください。

Pull request は [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) の規約に従い、可能な限りテストカバレッジを含めてください。コードエディタを使用する場合は [docs/COLLABORATION_RULES.md](docs/COLLABORATION_RULES.md) を参照してください。

---

## 謝辞

このプロジェクトは [nolze](https://github.com/nolze) による [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) のフォークとして始まりました。nolze 氏は元の Python ベースの Wi-Fi スキャナを構築しました。その後、アプリは Swift と SwiftUI、CoreWLAN で完全に書き直され、ネイティブ macOS アプリケーションへと進化しました。

---

## ライセンス

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA。詳細は [LICENSE](LICENSE) を参照。

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
