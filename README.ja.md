# WiFi Lens

**macOS 向けのネイティブなオープンソース Wi-Fi アナライザおよびネットワーク診断アプリ。**

チャンネルの混雑を可視化し、接続の問題を解決し、Wi-Fi ローミングを検証——すべて Mac 上でローカルに実行します。

[![最新リリース](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![ライセンス](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>オープンソース版をダウンロード</strong></a>
  ·
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746"><strong>WiFi Lens Pro を入手</strong></a>
  ·
  <a href="https://wifi-lens.shiinalabs.com">公式サイト</a>
</p>

macOS 14+ · Intel および Apple Silicon · テレメトリなし

<img alt="macOS 上で Wi-Fi スペクトラム分析を表示する WiFi Lens" src="assets/screenshot-swiftui.png" width="800">

## オープンソース版か Pro か？

| オープンソース版 | WiFi Lens Pro |
|---|---|
| 無料・オープンソース — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) | 一回買いの Mac App Store 版 — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) |
| 3 バンド Wi-Fi スキャンとスペクトル分析 | オープンソース版の全機能を含む |
| チャンネル品質、ネットワーク詳細、ローミングテスト | スペクトラムセッション録画——時間経過によるキャプチャと再生 |
| ネットワーク自己診断、BLE スキャナ、MCP サーバー | 期間をまたぐスペクトルの並列比較 |
| PNG/CSV エクスポート · Sparkle アップデート | 常駐メニューバー · タイムラインとトレンド · Mac App Store アップデート |

> 両版のコア Wi-Fi 分析機能は同一です。Pro は専門ワークフロー向けにスペクトル録画、比較、常駐メニューバー、タイムラインを追加します。

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

---

## WiFi Lens について

WiFi Lens は、SwiftUI、CoreWLAN、CoreBluetooth で開発したネイティブ macOS Wi-Fi・Bluetooth アナライザです。周辺の無線ネットワークと BLE デバイスをリアルタイムで表示し、接続問題の診断、混雑の少ないチャンネルの選択、アクセスポイント間のローミング動作の確認に役立ちます。

このリポジトリでは無料のオープンソース版を提供しています。WiFi Lens Pro は別売りの有料版で、スペクトル録画、比較、常駐メニューバー、タイムライン機能を追加します。

**典型的なユースケース：**

- 🏠 **ホームネットワークの調整：** 近隣で混雑しているチャンネルを見つけ、ルータをより空いているチャンネルに移します。
- 🏢 **オフィス Wi-Fi の監査：** 2.4、5、6 GHz の 3 バンドをスキャンし、デッドゾーンや設定ミスのある AP を見つけます。
- 🚶 **ローミングの検証：** 建物内を移動しながら AP の切り替えを記録し、タイムラインチャートで遷移を確認します。
- 🎧 **BLE デバイスのトラブルシューティング：** Bluetooth 周辺機器の RSSI 推移を追跡し、通信範囲や干渉の問題を特定します。

---

## 機能

| カテゴリ | 機能 | エディション |
|----------|-----------|---------|
| 📡 **Wi-Fi スキャン** | 2.4、5、6 GHz バンド全体でのリアルタイムスキャン、ネットワークごとの信号強度を表示 | OSS & Pro |
| 📊 **スペクトルビュー** | チャンネル占有を一目で示すガウスベル曲線チャート | OSS & Pro |
| 🎯 **チャンネル品質** | 混雑スコアと地域ベースの推奨、あなたの規制ドメインに調整済み | OSS & Pro |
| 🔍 **ネットワーク詳細** | PHY 世代、チャンネル幅、802.11k/r/v ローミング、WPA3、隠し SSID | OSS & Pro |
| 📶 **接続情報** | IP、ゲートウェイ、DNS、MAC、チャンネル、Tx レート、セキュリティサマリー | OSS & Pro |
| 🩺 **ネットワーク自己診断** | ワンクリックの接続診断——パス、DNS、HTTPS、プロキシ到達性を証拠に基づいて判定 | OSS & Pro |
| 📈 **タイムラインとトレンド** | 設定可能なスキャン間隔でネットワークごとの信号履歴を時間経過とともに表示 | Pro のみ |
| 🔄 **ローミングテスト** | タイムラインチャート、範囲セレクタ、セッション保存/読み込み機能付き AP 遷移モニタリング | OSS & Pro |
| 🗺️ **チャンネルヒートマップ** | バンドごとの占有ヒートマップですぐに混雑パターンを特定 | OSS & Pro |
| 🎬 **スペクトル録画** | 時間経過によるスペクトルの変化をキャプチャして再生 | Pro のみ |
| 🔭 **スペクトル比較** | 期間をまたぐスペクトルの並列比較 | Pro のみ |
| 🎧 **BLE スキャナ** | Bluetooth LE デバイス発見、RSSI 分析、トレンドチャート、デバイス追跡 | OSS & Pro |
| 🎨 **スマートカラーリング** | SSID に基づく一貫した色割り当て。同じネットワークには同じ色を使用 | OSS & Pro |
| 📍 **メニューバー** | メニューバーに常駐——アイコンをクリックするだけでいつでもアナライザを起動 | Pro のみ |
| 🔒 **プライバシーファースト** | テレメトリと利用状況分析なし。Wi-Fi スキャンデータは Mac 内に保持 | OSS & Pro |
| 🌐 **MCP サーバー** | 外部ツール連携用の内蔵 HTTP API（`127.0.0.1:19840`） | OSS & Pro |
| 🔄 **自動アップデート** | GitHub 版で任意の Sparkle アップデート確認を提供 | OSS & Pro |
| 📤 **エクスポート** | バンドごとのチャートを PNG 画像または CSV データとして保存 | OSS & Pro |
| 🌍 **ローカライズ** | 英語、ドイツ語、スペイン語、日本語、簡体字中国語 | OSS & Pro |

**Pro のみ**と記載された機能を除き、すべての機能がオープンソース版に含まれます。Pro はオープンソース版の全機能に加え、録画・比較・メニューバー・タイムラインツールを提供します。

---

## 設計

**ネイティブ macOS UI。** CoreWLAN は Wi-Fi ハードウェアと直接通信し、SwiftUI は Mac ネイティブのコントロールとウインドウ動作を提供します。

**地域規制を考慮した推奨。** WiFi Lens はシステムの地域設定、ハードウェア機能、周辺 AP の国コードから規制ドメインを推定します。DFS、屋内限定、6 GHz AFC の要件に基づいて推奨チャンネルを絞り込みます。

**連動するビュー。** テーブルでネットワークを選択すると、各チャートでも同じネットワークが強調表示されます。ベル曲線にポインタを合わせると SSID を確認できます。

**オープンソース版のツール。** PNG と CSV を書き出したり、ローミングセッションを保存・読み込みしたりできます。ローカル MCP サーバーを使って WiFi Lens を自分のツールに接続できます。

---

## ダウンロード

**macOS 14 (Sonoma) 以降**が必要。Intel および Apple Silicon Mac の両方で動作します。6 GHz 帯のスキャンには Wi-Fi 6E/7 ハードウェアが必要です。

- **オープンソース版** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest)（無料、任意の Sparkle 自動アップデート付き）
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746)（対応地域）

> [!IMPORTANT]
> macOS 14 以降では、Wi-Fi SSID を読み取るために**位置情報サービス**を有効にする必要があります。
> **システム設定 → プライバシーとセキュリティ → 位置情報サービス**を開き、確認が表示されたら WiFi Lens を有効にしてください。

> 🌐 **公式サイト：** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) では、スクリーンショット、機能紹介、AI/MCP ワークフロー、FAQ を掲載しています。

## プライバシー

WiFi Lens は利用状況分析、クラッシュテレメトリ、Wi-Fi スキャンデータを収集しません。

- **位置情報サービス：** macOS が Wi-Fi SSID 名を提供するために必要です。WiFi Lens は GPS 位置を読み取りません。
- **地域検出：** WiFi Lens はシステムの地域設定、ハードウェアが報告するチャンネル一覧、周辺 AP の国コードをデバイス上で使用します。
- **ネットワーク自己診断：** 実行時に `example.com` を名前解決し、設定されたプロキシエンドポイントへの到達性を確認する場合があります。
- **MCP サーバー：** 任意のサーバーは `127.0.0.1` にバインドします。有効にした後に限り、ローカルツールがスキャンデータへアクセスできます。
- **アップデート確認：** GitHub 版は、手動で確認したとき、または自動確認を有効にしたときに GitHub へ接続します。

---

## 開発

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

# ビルド
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# テスト実行
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests

# Xcode で開く
xed WiFiLens.xcodeproj
```

製品名は `WiFi Lens.app`（スペース付き）。

アーキテクチャ、テスト、ロードマップのドキュメントは [docs/](docs/) にあります。

---

## 貢献

バグレポートと機能アイデアを歓迎します。[issue](https://github.com/SHIINASAMA/wifi-lens/issues) を開くか、[discussion](https://github.com/SHIINASAMA/wifi-lens/discussions) を開始してください。

Pull request は [.agents/references/project/ARCHITECTURE.md](.agents/references/project/ARCHITECTURE.md) の規約に従い、可能な限りテストを含めてください。コーディングエージェントを使用する場合は [.agents/references/collaboration-rules.md](.agents/references/collaboration-rules.md) を参照してください。

**連絡先：** [X の @WiFiLens](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

## 謝辞

このプロジェクトは [nolze](https://github.com/nolze) による [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) のフォークとして始まりました。nolze 氏は元の Python ベースの Wi-Fi スキャナを構築しました。その後、アプリは Swift と SwiftUI、CoreWLAN で完全に書き直され、ネイティブ macOS アプリケーションへと進化しました。

---

## ライセンス

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA。詳細は [LICENSE](LICENSE) を参照。
