# WiFi Lens

**macOS 向けネイティブオープンソースネットワーク診断アプリ、Wi-Fi 分析を内蔵。**

接続問題の診断、Wi-Fi チャンネル混雑の分析、ローミング動作の検証——すべてローカルで処理されます。

[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)

<p align="center"><img alt="WiFi Lens スペクトル分析" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>オープンソース版をダウンロード</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746"><strong>WiFi Lens Pro を入手</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">公式サイト</a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; テレメトリなし</p>

<p align="center">
  🔒 <strong>ローカルファーストのプライバシー</strong> — アカウント不要、クラウド送信なし<br>
  🩺 <strong>エビデンスに基づく診断</strong> — パス・DNS・HTTPS・プロキシの到達性チェック<br>
  🤖 <strong>AI ワークフロー向け MCP</strong> — Claude Desktop からライブ Wi-Fi データに接続
</p>

---

<p align="center">
  <a href="README.md">🇺🇸 English</a> · <a href="README.de.md">🇩🇪 Deutsch</a> · <a href="README.es-ES.md">🇪🇸 Español</a> · <a href="README.fr.md">🇫🇷 Français</a> · <a href="README.zh-Hans.md">🇨🇳 简体中文</a> · 🇯🇵 日本語
</p>
<p align="center">
  <a href="#機能">機能</a> · <a href="#エディション">エディション</a> · <a href="#ai--mcp-統合">AI / MCP</a> · <a href="#プライバシー">プライバシー</a> · <a href="#インストール">インストール</a> · <a href="#開発">開発</a> · <a href="#コントリビュート">コントリビュート</a> · <a href="#ライセンス">ライセンス</a>
</p>

---

## 機能

### コア · OSS & Pro

| 機能 | 説明 | ステータス |
|------|------|----------|
| 📡 Wi-Fi スキャン | 2.4 / 5 / 6 GHz 帯域のリアルタイムスキャン | 安定 |
| 📊 スペクトルビュー | チャンネル占有率のガウス曲線チャート | 安定 |
| 🎯 チャンネル品質 | 混雑スコアと地域ベースの推奨 | 安定 |
| 🔍 ネットワーク詳細 | PHY 世代、チャンネル幅、802.11k/r/v、WPA3 | 安定 |
| 📶 接続情報 | IP、ゲートウェイ、DNS、MAC、Tx レート、セキュリティ | 安定 |
| 🚶 ローミングテスト | AP 遷移モニタリングとセッション管理 | 安定 |
| 🗺️ チャンネルヒートマップ | バンドごとの占有ヒートマップ | 安定 |
| 🎧 BLE スキャナ | Bluetooth LE デバイス発見、RSSI 分析、追跡 | 安定 |
| 🎨 スマートカラーリング | SSID ベースの一貫した色割り当て | 安定 |
| 🌐 MCP サーバー | AI ツール連携用の内蔵 HTTP API | 安定 |
| 📤 エクスポート | チャートを PNG または CSV で保存 | 安定 |
| 🔒 プライバシーファースト | テレメトリなし、スキャンデータはローカル保持 | 安定 |
| ⬆️ 自動アップデート | Sparkle（GitHub）または Mac App Store | 安定 |
| 🌍 ローカライズ | 英語・ドイツ語・スペイン語・日本語・中国語 | 安定 |
| 🩺 ネットワーク自己診断 | パス・DNS・HTTPS・プロキシのワンクリック診断 | プレビュー |
| 📻 APレーダー | 選択した AP を音声パルスで追跡 | プレビュー |

### Pro 専用

| 機能 | 説明 | ステータス |
|------|------|----------|
| 📈 イベントタイムライン | 接続イベント履歴——ローミング・切断・信号変化 | プレビュー |
| 📋 統計 | タイムライン履歴を期間比較付きで分析 | プレビュー |
| 💡 インサイト | エビデンスにリンクされた説明可能な発見 | プレビュー |
| 🎬 スペクトル録画 | 時間経過によるスペクトル変化を記録・再生 | 安定 |
| 📱 メニューバー | macOS メニューバーからのクイックアクセス | 安定 |

---

## エディション

| | オープンソース | WiFi Lens Pro |
|--|------------|--------------|
| 価格 | 無料 | 買い切り |
| ソース | [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) | [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) |
| コア分析 | ✅ 上記の全機能 | ✅ OSS の全機能 |
| 専用ツール | — | イベントタイムライン · 統計 · インサイト · 録画 · メニューバー |
| アップデート | Sparkle 自動更新 | Mac App Store |

> 両エディションは同じ分析エンジンを共有しています。Pro はプロフェッショナルなモニタリングワークフローを追加します。

---

## AI / MCP 統合

WiFi Lens には内蔵 MCP サーバーがあり、AI アシスタントがローカルの Wi-Fi データを読み取れます。設定で有効にし、Claude Desktop に追加してください：

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

接続後、Claude に _「近くで混雑しているチャンネルは？」_ や _「ゲートウェイは到達可能？」_ と尋ねられます。サーバーは `127.0.0.1` のみにバインドされ、意図的にルーティングしない限りデータは外部に出ません。

詳しくは [AI ワークフローガイド](https://wifi-lens.shiinalabs.com/ai-mcp/) をご覧ください。

---

<table>
<tr>
<td width="50%" align="center"><img alt="ネットワーク自己診断画面" src="assets/screenshot-selfcheck.webp" width="100%"><sub>ネットワーク自己診断</sub></td>
<td width="50%" align="center"><img alt="イベントタイムライン" src="assets/screenshot-timeline.webp" width="100%"><sub>イベントタイムライン（Pro）</sub></td>
</tr>
</table>

---

## プライバシー

WiFi Lens は利用状況の分析、クラッシュテレメトリ、Wi-Fi スキャンデータを収集しません。

- **位置情報サービス：** Wi-Fi SSID 名の読み取りに macOS が必要とする権限です。GPS 位置情報は読み取りません。
- **地域検出：** システムの言語設定、ハードウェアのチャンネルリスト、近隣 AP の国コードをデバイス上で使用します。
- **ネットワーク自己診断：** 公開エンドポイント（`www.apple.com`、`www.msftconnecttest.com`）を解決し、設定されたプロキシの到達性を確認する場合があります。
- **MCP サーバー：** `127.0.0.1` のみにバインド。有効化後にのみローカルツールがデータにアクセスできます。
- **アップデート確認：** GitHub 版はアップデート確認時に GitHub にアクセスします。

📋 [セキュリティポリシー](SECURITY.md) · 📝 [変更履歴](https://github.com/SHIINASAMA/wifi-lens/releases) · ❓ [FAQ](https://wifi-lens.shiinalabs.com/faq/) · 🌐 [プライバシーポリシー全文](https://wifi-lens.shiinalabs.com/privacy/)

---

## インストール

**macOS 14 (Sonoma) 以降**が必要です。Intel Mac と Apple Silicon の両方で動作します。6 GHz スキャンには Wi-Fi 6E/7 ハードウェアが必要です。

- **オープンソース版** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest)（無料、Sparkle 自動更新）
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

> [!IMPORTANT]
> macOS 14 以降では Wi-Fi SSID 名の読み取りに**位置情報サービス**の有効化が必要です。**システム設定 → プライバシーとセキュリティ → 位置情報サービス**で WiFi Lens を許可してください。

---

## 開発

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' build
```

アーキテクチャドキュメントは [docs/](docs/) にあります。

---

## コントリビュート

バグレポートや機能のアイデアを歓迎します。[コントリビューションガイドライン](.github/CONTRIBUTING.md)をご覧ください。大きな貢献をされた方には Pro プロモコードを贈呈する場合があります——[コントリビューター認定](.github/CONTRIBUTING.md#contributor-recognition)をご参照ください。

**連絡先：** [X の @WiFiLens](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer). MAC ベンダーデータは [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/) より——[サードパーティ通知](docs/THIRD-PARTY-NOTICES.md)をご参照ください。

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — [LICENSE](LICENSE) をご参照ください。
