# Implementation Roadmap — Three-D Stack (3DS)

_Date: 2026-04-08_

---

## Milestone Overview

```
v0.1.0 (MVP)   ── apps/ + core/ 実装、README 更新
v0.2.0         ── Ansible ロール実装
v0.3.0         ── DevContainer + CI
v1.0.0         ── ドキュメント整備、Ansible Galaxy 公開準備
```

---

## v0.1.0 — MVP: 動作するスターターキット

**ゴール:** clone してすぐに Dewy + Docker + DVB を動かせるサンプルが揃っている状態

| # | Issue 候補 | 成果物 |
|---|-----------|--------|
| 1 | `[FEAT] リポジトリ構造の再設計` | `apps/`, `core/` ディレクトリ作成、`container/` 削除 |
| 2 | `[FEAT] sample-app テンプレート実装` | `apps/sample-app/dewy.env`, `compose.yaml`, `hooks/` |
| 3 | `[FEAT] グローバルフック実装` | `core/global-hooks/backup.sh`, `notify.sh` |
| 4 | `[FEAT] README を新構造に合わせて更新` | `README.md` のディレクトリ図・Getting Started 更新 |

**完了条件:**
- `apps/sample-app/` を VM にコピーし、`docker compose up -d` と `dewy container` で動作する
- `before-deploy.sh` 実行で DVB スナップショットが `./backups/` に作成される

---

## v0.2.0 — Ansible ロール実装

**ゴール:** `ansible-playbook setup-node.yml` 1コマンドで VM が 3DS 稼働状態になる

| # | Issue 候補 | 成果物 |
|---|-----------|--------|
| 5 | `[FEAT] 3ds_base ロール実装` | Docker インストール・ネットワーク・ディレクトリ構成 |
| 6 | `[FEAT] dewy_setup ロール実装` | Dewy バイナリ配置・systemd ユニット生成 |
| 7 | `[FEAT] Inventory テンプレート作成` | `inventories/local/`, `inventories/proxmox/` |
| 8 | `[FEAT] setup-node.yml Playbook 実装` | VM ブートストラップの E2E Playbook |
| 9 | `[FEAT] OrbStack / VirtualBox でのローカル検証` | Molecule または手動 smoke test |

**完了条件:**
- OrbStack VM に対して `ansible-playbook setup-node.yml` が通り、Dewy サービスが起動する
- 同じ Playbook を Proxmox VE VM に対して実行しても動作する

---

## v0.3.0 — DevContainer & CI

**ゴール:** コントリビューターがすぐに開発を始められ、PR に静的検査が走る

| # | Issue 候補 | 成果物 |
|---|-----------|--------|
| 10 | `[FEAT] devcontainer.json 実装` | ansible-core / yamllint / shellcheck / molecule 環境 |
| 11 | `[FEAT] GitHub Actions lint CI 実装` | `shellcheck` + `yamllint` + `ansible-lint` |
| 12 | `[FEAT] .gitmessage の規約ドキュメント化` | `docs/contributing.md` |

**完了条件:**
- DevContainer 内で `ansible-lint ansible/` と `shellcheck apps/**/hooks/*.sh` がエラーなし通過
- PR 作成時に lint CI が自動実行される

---

## v1.0.0 — ドキュメント整備・公開準備

**ゴール:** ユーザーが README だけで 3DS を導入でき、Ansible Galaxy 公開の準備が整う

| # | Issue 候補 | 成果物 |
|---|-----------|--------|
| 13 | `[FEAT] docs/getting-started.md 執筆` | Proxmox VE 優先のセットアップガイド |
| 14 | `[FEAT] docs/blue-green.md 執筆` | スロット運用ガイド |
| 15 | `[FEAT] docs/backup-restore.md 執筆` | DVB バックアップ・リストア手順 |
| 16 | `[FEAT] docs/infrastructure-notes.md 執筆` | Proxmox / OrbStack 固有の設定メモ |
| 17 | `[FEAT] Ansible Galaxy メタデータ追加` | `ansible/galaxy.yml`, `README` の `requirements.yml` 例 |
| 18 | `[FEAT] CHANGELOG.md 初版作成` | v1.0.0 リリースノート |

**完了条件:**
- 初見のインフラエンジニアが README → `docs/getting-started.md` の手順だけで環境構築できる
- `ansible-galaxy install` または `git clone` どちらでも導入できる導線が整っている

---

## 優先実装順序

```
Issue 1 (構造整理)
  └─ Issue 2 (sample-app)
       └─ Issue 3 (global-hooks)
            └─ Issue 4 (README 更新)
                 └─ Issue 5-9 (Ansible)
                      └─ Issue 10-12 (DevContainer / CI)
                           └─ Issue 13-18 (ドキュメント / 公開)
```
