---
description: Git commit (stage + commit)
allowed-tools:
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git add:*)
  - Bash(git commit:*)
---

変更をコミットしてください。以下の手順に従うこと:

1. `git status` と `git diff` と `git log --oneline -5` を並列実行
2. 変更内容を分析し、リポジトリのコミットメッセージスタイルに合わせたコミットメッセージを作成
3. 関連ファイルを `git add` でステージし、コミットを作成
4. コミットメッセージの末尾に `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` を付与
5. コミット後に `git status` で成功を確認
