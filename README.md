# 🚽 トイレロワイヤル / Toilet Royale

「流すか、流されるか。」

巨大トイレの水流に流されずに最後まで残ることを目指す物理パーティアクションゲーム。
詳細は [docs/PROJECT_BRIEF.md](docs/PROJECT_BRIEF.md) と [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) を参照。

## v0.1 プロトタイプの実行方法

ビルド不要。ブラウザで開くだけで動きます。

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

- `prototype/sim.js` — 物理・状態機械（純ロジック、Node でも動く）
- `prototype/game.js` — 描画・入力・演出
- `prototype/index.html` — エントリポイント
- `specs/` — 各バージョンの実装スペック
- `docs/` — 企画・設計・ワークフロー・開発ログ
