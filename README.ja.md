# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Build%20&%20Release/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Build+%26+Release%22)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)

シンプルなオープンソースの macOS 向け Wi-Fi チャンネル・信号強度アナライザです。
SwiftUI、CoreWLAN、Sparkle で構築されています。

![screenshot](assets/screenshot-swiftui.png)

🇺🇸 [English](README.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

## 機能

- 2.4 GHz、5 GHz、6 GHz 帯域のリアルタイム Wi-Fi スキャン
- 帯域ごとのガウスベル曲線チャート（動的 Y 軸スケーリング対応）
- 帯域ごとの固定およびドラッグによるズーム
- SSID に基づく決定論的な色割り当て
- ネイティブカラムソート、行選択、チャートハイライト機能付き統合ネットワークテーブル
- 全帯域で SSID または BSSID によるネットワークフィルタリング
- 802.11 ケイパビリティ詳細：PHY 世代、チャンネル幅、802.11k/r/v ローミング、WPA3、隠し SSID
- 接続中ネットワークのステータス：IP、ゲートウェイ、DNS、MAC、チャンネル、Tx レート、セキュリティ
- チャンネル混雑分析付き接続品質スコア
- ネットワークごとの信号履歴トレンドチャート
- ローミングテスト：タイムラインチャート、範囲セレクタ、セッション保存/読み込み機能付き AP 遷移モニタリング
- 帯域ごとのチャンネル占有ヒートマップ
- 設定可能なスキャン間隔（1〜10 秒）
- 帯域ごとのチャートを PNG または CSV でエクスポート
- 外部ツール連携用 MCP（Model Context Protocol）HTTP サーバー
- Sparkle 自動アップデート対応
- クラッシュレポートと構造化ログ
- 英語、簡体字中国語、日本語ローカライゼーション

## 動作環境

- macOS 14.0 (Sonoma) 以降

> [!IMPORTANT]
> macOS 14 以降では、Wi-Fi SSID の読み取りに位置情報サービスの権限が必要です。
> **システム設定 → プライバシーとセキュリティ → 位置情報サービス** を開き、
> プロンプトが表示されたらアプリを有効にしてください。

## プライバシー

WiFi Lens は個人情報、使用状況分析、テレメトリを一切収集、保存、送信しません。すべてのデータはあなたの Mac 上に留まります。

- **位置情報サービス** — macOS が Wi-Fi SSID 名を公開するために必要です。WiFi Lens が GPS 座標にアクセスすることは決してありません。
- **地域検出** — チャンネル推奨はシステムロケール、ハードウェア報告のチャンネルリスト、近隣 AP の国コードを使用して規制ドメインを推測します。この推測は完全にデバイス上で実行されます。
- **MCP サーバー** — `127.0.0.1` にバインドされています。明示的に他の場所にルーティングしない限り、スキャンデータがマシンの外部に出ることはありません。

## ダウンロード

[最新リリースを見る](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)

### Gatekeeper の回避策

このアプリケーションは署名されていないため、macOS Gatekeeper がブロックする場合があります。

- アプリアイコンを **右クリック** → **開く** → ダイアログで確認する、または
- ターミナルで以下を実行：
  ```sh
  xattr -d com.apple.quarantine /Applications/WiFi\ Lens.app
  ```

## 開発

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens/WiFiLens

# ビルド
xcodebuild -project WiFiLens.xcodeproj -scheme WiFiLens -configuration "Debug-OSS" -destination 'platform=macOS' build

# テスト実行
xcodebuild -project WiFiLens.xcodeproj -scheme WiFiLens -configuration "Debug-OSS" -destination 'platform=macOS' test

# Xcode で開く
xed WiFiLens.xcodeproj
```

アーキテクチャ、ロードマップ、既知の問題に関するドキュメントは [docs/](docs/) ディレクトリを参照してください。

## 謝辞

このプロジェクトは [nolze](https://github.com/nolze) による [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) のフォークとして始まりました。nolze 氏は元の Python ベースの Wi-Fi スキャナを構築しました。その後、アプリは Swift と SwiftUI、CoreWLAN で完全に書き直され、新しい名前のネイティブ macOS アプリケーションへと進化しました。

## ライセンス

```
Copyright 2020 nolze
Copyright 2026 SHIINASAMA

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
