# AI Workflow

## Roles

### Human

- 企画判断
- 面白さ判断
- 仕様の最終決定
- Pull Requestの最終承認

### Claude Code

- 実装
- リファクタリング
- テスト追加
- ドキュメント更新
- Codexレビュー後の修正

### Codex

- コード・構造・設定の実装と実行テスト（共有AGENTS.mdの役割分担に従う）
- 差分レビュー
- バグ検出
- 設計レビュー
- セキュリティレビュー
- Claude Codeが詰まったときの救援

## Basic Flow

1. Human creates or selects a GitHub Issue.
2. Human or Claude Code writes a small spec.
3. Claude Code implements the change on a feature branch.
4. Codex reviews the diff via codex-plugin-cc.
5. Claude Code fixes issues found by Codex.
6. Human plays the build and reviews the result.
7. Human approves merge.
8. Development log is updated.