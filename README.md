# 🚽 トイレロワイヤル / Toilet Royale

「流すか、流されるか。」

巨大トイレの水流に流されずに最後まで残ることを目指す物理パーティアクションゲーム。
詳細は [docs/PROJECT_BRIEF.md](docs/PROJECT_BRIEF.md) と [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) を参照。

## v0.2 3Dグレーボックス版（Godot 4）の実行方法

最終的な方向性は3D物理パーティアクションです。v0.2 は「3D空間で巨大トイレに
吸い込まれるだけで面白いか」を検証するグレーボックス版です。

[Godot 4.3 以降](https://godotengine.org/download) をインストールして:

```bash
# エディタで開く場合
godot --path game --editor

# 直接実行する場合
godot --path game
```

またはGodotエディタのプロジェクトマネージャーから `game/project.godot` をインポートして実行（F5）。

### 操作（3D版）

| キー | 動作 |
|---|---|
| WASD / 矢印 | 移動 |
| Space | ジャンプ |
| R | リセット |

ステージ全体が巨大トイレの上。一定時間ごとに水流が発生し、中央の便器穴へ
吸い込まれます。空中にいると強く吸われるので、水流中のジャンプは危険です。

## v0.1 2Dプロトタイプの実行方法（参考実装）

v0.1 は「水流に吸い込まれる遊びが成立するか」を検証した 2D Canvas 版です。
完成版の土台ではなく参考実装として残しています。ビルド不要。ブラウザで開くだけで動きます。

```bash
open prototype/index.html
```

またはローカルサーバー経由:

```bash
python3 -m http.server -d prototype 8000
# → http://localhost:8000 を開く
```

### 操作

| キー | 動作 |
|---|---|
| ← → / A D | 左右移動 |
| Space / W / ↑ | ジャンプ |
| R | リセット |

一定時間ごとに中央の巨大トイレが水流を発生させ、プレイヤーを吸い込みます。
便器に落ちると脱落（自動リスパウン）。空中にいると強く吸われるので注意。

## テスト

```bash
node prototype/test_sim.js
```

## 構成

- `game/` — v0.2以降の3Dゲーム本体（Godot 4）
  - `scenes/main.tscn` — メインシーン（ステージ・カメラ・UI）
  - `scenes/player.tscn` — プレイヤー
  - `scripts/` — GDScript（flush_controller.gd が水流ロジックの中核）
- `prototype/` — v0.1 の2D Canvas版（参考実装）
  - `sim.js` — 物理・状態機械（純ロジック、Node でも動く）
  - `game.js` — 描画・入力・演出
  - `index.html` — エントリポイント
- `specs/` — 各バージョンの実装スペック
- `docs/` — 企画・設計・ワークフロー・開発ログ
