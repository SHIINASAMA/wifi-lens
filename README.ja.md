<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-swiftui.png">
  <img alt="WiFi Lens macOS Wi-Fi スペクトラムアナライザ" src="assets/screenshot-swiftui.png" width="800">
</picture>

# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)
[![Website](https://img.shields.io/badge/website-wifi--lens.shiinalabs.com-2563eb)](https://wifi-lens.shiinalabs.com)

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

**Wi-Fi ネットワークを分析・最適化するためのネイティブ macOS ツール。**

<p align="center">
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746">
    <img src="assets/appstore-badge-en.svg" alt="Mac App Store で WiFi Lens Pro をダウンロード" width="240">
  </a>
</p>

---

## WiFi Lens について

WiFi Lens は、SwiftUI、CoreWLAN、CoreBluetooth で開発したネイティブ macOS Wi-Fi・Bluetooth アナライザです。周辺の無線ネットワークと BLE デバイスをリアルタイムで表示し、接続問題の診断、混雑の少ないチャンネルの選択、アクセスポイント間のローミング動作の確認に役立ちます。

このリポジトリでは無料のオープンソース版を提供しています。WiFi Lens Pro は追加機能を含む別売りの有料版です。

**典型的なユースケース：**

- 🏠 **ホームネットワークの調整：** 近隣で混雑しているチャンネルを見つけ、ルータをより空いているチャンネルに移します。
- 🏢 **オフィス Wi-Fi の監査：** 2.4、5、6 GHz の 3 バンドをスキャンし、デッドゾーンや設定ミスのある AP を見つけます。
- 🚶 **ローミングの検証：** 建物内を移動しながら AP の切り替えを記録し、タイムラインチャートで遷移を確認します。
- 🎧 **BLE デバイスのトラブルシューティング：** Bluetooth 周辺機器の RSSI 推移を追跡し、通信範囲や干渉の問題を特定します。

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
| 🎨 **スマートカラーリング** | SSID に基づく一貫した色割り当て。同じネットワークには同じ色を使用 |
| 🔒 **プライバシーファースト** | テレメトリと利用状況分析なし。Wi-Fi スキャンデータは Mac 内に保持 |
| 🌐 **MCP サーバー** | 外部ツール連携用の内蔵 HTTP API（`127.0.0.1:19840`） |
| 🔄 **自動アップデート** | GitHub 版で任意の Sparkle アップデート確認を提供 |
| 📤 **エクスポート** | バンドごとのチャートを PNG 画像または CSV データとして保存 |
| 🌍 **ローカライズ** | 英語、ドイツ語、スペイン語、日本語、簡体字中国語 |

---

## 設計

**ネイティブ macOS UI。** CoreWLAN は Wi-Fi ハードウェアと直接通信し、SwiftUI は Mac ネイティブのコントロールとウインドウ動作を提供します。

**地域規制を考慮した推奨。** WiFi Lens はシステムの地域設定、ハードウェア機能、周辺 AP の国コードから規制ドメインを推定します。DFS、屋内限定、6 GHz AFC の要件に基づいて推奨チャンネルを絞り込みます。

**連動するビュー。** テーブルでネットワークを選択すると、各チャートでも同じネットワークが強調表示されます。ベル曲線にポインタを合わせると SSID を確認できます。

**オープンソース版のツール。** PNG と CSV を書き出したり、ローミングセッションを保存・読み込みしたりできます。ローカル MCP サーバーを使って WiFi Lens を自分のツールに接続できます。

---

## ダウンロード

[![最新リリースをダウンロード](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![Mac App Store で WiFi Lens Pro をダウンロード](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

GitHub Releases ではオープンソース版を提供しています。WiFi Lens Pro は対応地域の Mac App Store で入手できます。

macOS 14 (Sonoma) 以降が必要。Intel および Apple Silicon Mac の両方で動作します。

> 🌐 **公式サイト：** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) では、スクリーンショット、機能紹介、AI/MCP ワークフロー、FAQ を掲載しています。

> [!IMPORTANT]
> macOS 14 以降では、Wi-Fi SSID を読み取るために**位置情報サービス**を有効にする必要があります。
> **システム設定 → プライバシーとセキュリティ → 位置情報サービス**を開き、確認が表示されたら WiFi Lens を有効にしてください。

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

---

## 謝辞

このプロジェクトは [nolze](https://github.com/nolze) による [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) のフォークとして始まりました。nolze 氏は元の Python ベースの Wi-Fi スキャナを構築しました。その後、アプリは Swift と SwiftUI、CoreWLAN で完全に書き直され、ネイティブ macOS アプリケーションへと進化しました。

---

## ライセンス

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA。詳細は [LICENSE](LICENSE) を参照。

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
