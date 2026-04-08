# Repository Guide — Three-D Stack (3DS)

_全ファイル・ディレクトリの構成と役割を解説するリファレンスドキュメント。_

---

## 全体構成

```
three-d-stack/
├── apps/                          # アプリケーション単位の設定
│   └── sample-app/
│       ├── dewy.env.example
│       ├── hooks/
│       │   ├── before-deploy.sh
│       │   └── after-deploy.sh
│       └── compose.yaml
├── core/
│   └── global-hooks/
│       ├── backup.sh
│       └── notify.sh
├── ansible/
│   ├── ansible.cfg
│   ├── inventories/
│   │   ├── local/
│   │   │   ├── hosts.ini
│   │   │   └── group_vars/all.yml
│   │   └── proxmox/
│   │       ├── hosts.ini
│   │       └── group_vars/all.yml
│   ├── playbooks/
│   │   ├── setup-node.yml
│   │   └── deploy-app.yml
│   └── roles/
│       ├── 3ds_base/
│       │   ├── tasks/main.yml
│       │   ├── handlers/main.yml
│       │   ├── defaults/main.yml
│       │   └── meta/main.yml
│       └── dewy_setup/
│           ├── tasks/main.yml
│           ├── handlers/main.yml
│           ├── defaults/main.yml
│           ├── templates/dewy.service.j2
│           └── meta/main.yml
├── docs/
├── .devcontainer/
│   └── devcontainer.json
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yaml
│   │   └── feature_ticket.yaml
├── .gitignore
├── .gitmessage
├── LICENSE
└── README.md
```

---

## `apps/` — アプリケーション設定

アプリケーション 1 つにつき 1 ディレクトリ。Dewy が管理するコンテナとその周辺リソースに関するファイルをすべてここに集約する。

### 役割分担の原則

| コンポーネント | 管理者 |
|---|---|
| アプリコンテナの起動・更新・ローリング | **Dewy** (`docker run` を直接実行) |
| DB / Redis / DVB などの周辺サービス | **Docker Compose** (`compose.yaml` で定義) |

---

### `apps/sample-app/dewy.env.example`

**種別:** テンプレートファイル（コミット対象）

Dewy の起動引数を環境変数として定義するテンプレート。実際に使用するファイルは `dewy.env`（`.gitignore` 対象）であり、このファイルをコピーして値を書き換えて使う。

```
cp dewy.env.example dewy.env
```

Ansible の `dewy_setup` ロールは、コントロールノード上に `dewy.env` が存在する場合に自動的に VM へ転送する。存在しない場合は警告を表示してサービス起動をスキップする。

| 変数 | 説明 |
|---|---|
| `DEWY_REGISTRY` | ポーリング対象の OCI レジストリ URL |
| `DEWY_PORT` | コンテナが公開するポート番号 |
| `DEWY_HEALTH_PATH` | トラフィック切替前にチェックする HTTP エンドポイント |
| `DEWY_REPLICAS` | 同一ノード上で起動するコンテナ数 |
| `DEWY_BEFORE_DEPLOY_HOOK` | デプロイ前に実行するスクリプトのパス |
| `DEWY_AFTER_DEPLOY_HOOK` | デプロイ後に実行するスクリプトのパス |
| `DEWY_NOTIFIER` | 通知先（Slack URL / SMTP など） |
| `DEWY_EXTRA_ARGS` | `docker run` に渡す追加オプション（`--` 以降） |

---

### `apps/sample-app/compose.yaml`

**種別:** Docker Compose 定義ファイル

アプリが依存する周辺サービス（DB・DVB）を定義する。**アプリコンテナ自体はここに書かない**（Dewy が管理するため）。

定義されているサービス:

| サービス | イメージ | 役割 |
|---|---|---|
| `db` | `postgres:16-alpine` | アプリのデータベース |
| `backup` | `offen/docker-volume-backup:v2.47.2` | ボリュームの定期バックアップ（毎日 02:00） |

**DVB の設定ポイント:**
- `db` コンテナに `docker-volume-backup.stop-during-backup: "true"` ラベルを付与し、バックアップ中に DB を停止して整合性を確保する
- バックアップ先は S3 互換ストレージ（デフォルトはコメントアウト）または `./backups/` ローカルディレクトリ
- `3ds-net` ネットワークは外部ネットワーク（Ansible の `3ds_base` ロールが作成）

---

### `apps/sample-app/hooks/before-deploy.sh`

**種別:** Dewy のデプロイ前フック（実行権限付き）

Dewy がコンテナを更新する**直前**に自動実行される。DVB でボリュームのスナップショットを取得し、デプロイが失敗した場合の復元ポイントを確保する。

**重要:** スクリプトが非ゼロで終了すると、Dewy はデプロイを中止する。スナップショット失敗 = デプロイ中断 という安全設計になっている。

処理フロー:
1. バックアップラベルを生成（例: `pre-deploy-sample-app-20260408T120000`）
2. `offen/docker-volume-backup` コンテナを一時起動してスナップショットを取得
3. アーカイブを `./backups/` に保存

---

### `apps/sample-app/hooks/after-deploy.sh`

**種別:** Dewy のデプロイ後フック（実行権限付き）

コンテナの更新が**正常完了した後**に実行される。デプロイ完了ログの出力と、以下のオプション処理のひな形をコメントで提供する:

- データベースマイグレーションの実行
- `core/global-hooks/notify.sh` を使った Slack 通知

---

## `core/` — 共有フックスクリプト

複数のアプリから再利用できる共通処理を管理する。各アプリのフックスクリプトからこのファイルを `source` して使う。

---

### `core/global-hooks/backup.sh`

**種別:** シェルスクリプトライブラリ（`source` して使う）

`run_backup <label> <volume1> [volume2 ...]` 関数を提供する。DVB の `docker run` 呼び出しを抽象化し、ボリューム名を可変長引数で受け取る。

**使用例:**
```sh
. ./core/global-hooks/backup.sh
run_backup "pre-deploy-myapp-$(date +%Y%m%dT%H%M%S)" db-data app-data
```

---

### `core/global-hooks/notify.sh`

**種別:** シェルスクリプトライブラリ（`source` して使う）

`notify_slack <message>` 関数を提供する。環境変数 `NOTIFY_SLACK_WEBHOOK` が未設定の場合は警告のみ出力して正常終了するため、Webhook が設定されていない環境でもフックスクリプトが失敗しない。

**使用例:**
```sh
. ./core/global-hooks/notify.sh
notify_slack "Deploy complete: myapp at $(date)"
```

---

## `ansible/` — Ansible による VM プロビジョニング

VM に Docker・Dewy・アプリ設定を自動でセットアップするための Ansible コードをすべて格納する。コントロールノード（手元の Mac）から SSH 経由で対象 VM に対して実行する。VM 側にリポジトリのクローンは不要。

---

### `ansible/ansible.cfg`

**種別:** Ansible 設定ファイル

`ansible-playbook` を `ansible/` ディレクトリから実行したときのデフォルト設定。

| 設定 | 値 | 説明 |
|---|---|---|
| `inventory` | `inventories/local/hosts.ini` | 省略時はローカル（OrbStack）を対象にする |
| `roles_path` | `roles` | ロールの検索パス |
| `host_key_checking` | `False` | SSH ホスト鍵確認をスキップ（開発環境向け） |
| `pipelining` | `True` | SSH 接続を再利用して実行速度を向上 |

---

### `ansible/inventories/local/hosts.ini`

**種別:** OrbStack ローカル VM 向けインベントリ

OrbStack の SSH 接続方式に合わせた設定。OrbStack では `ssh <user>@<machine>@orb` という特殊な形式を使うため、Ansible では以下のように定義する:

```ini
ansible_host=orb           # OrbStack の SSH ゲートウェイ
ansible_user=cyokozai@three-ds  # <user>@<machine> 形式
```

---

### `ansible/inventories/local/group_vars/all.yml`

**種別:** ローカル環境向け変数定義

OrbStack インベントリ配下の全ホストに適用される変数。

| 変数 | デフォルト値 | 説明 |
|---|---|---|
| `docker_version` | `"27"` | インストールする Docker Engine のメジャーバージョン |
| `three_ds_network` | `"3ds-net"` | アプリ間で共有する Docker ブリッジネットワーク名 |
| `three_ds_base_dir` | `"/opt/3ds"` | VM 上の 3DS ルートディレクトリ |
| `dewy_version` | `"2.14.0"` | インストールする Dewy のバージョン |
| `dewy_apps` | `[]` | セットアップ対象のアプリ名リスト（例: `["sample-app"]`） |

---

### `ansible/inventories/proxmox/hosts.ini`

**種別:** Proxmox VE 本番 VM 向けインベントリ

本番 VM のホスト名または IP アドレスを追記して使う。ローカルインベントリと同じロールを使うため、動作は同一。

---

### `ansible/inventories/proxmox/group_vars/all.yml`

**種別:** Proxmox 環境向け変数定義

ローカル環境と同じ変数セット。本番環境に合わせてバージョンやパスを上書きする場合はここを編集する。

---

### `ansible/playbooks/setup-node.yml`

**種別:** Playbook — VM ブートストラップ

対象 VM に `3ds_base` ロールを適用して、Docker・ネットワーク・ディレクトリ構造をセットアップする。アプリのデプロイは `deploy-app.yml` が担当。

**実行例:**
```bash
# OrbStack ローカル VM
ansible-playbook -i inventories/local playbooks/setup-node.yml

# Proxmox VE 本番 VM
ansible-playbook -i inventories/proxmox playbooks/setup-node.yml
```

---

### `ansible/playbooks/deploy-app.yml`

**種別:** Playbook — アプリのデプロイ・更新

`dewy_setup` ロールを適用し、指定アプリのファイルを VM に転送して systemd サービスを起動する。`app_name` 変数は必須。

**実行例:**
```bash
ansible-playbook -i inventories/local playbooks/deploy-app.yml \
  -e "app_name=sample-app"
```

**実行前提:** `apps/sample-app/dewy.env` がコントロールノードに存在すること。存在しない場合は警告のみでサービスは起動しない。

---

### `ansible/roles/3ds_base/`

**種別:** Ansible ロール — Docker 基盤セットアップ

VM への Docker インストールと 3DS の実行基盤を整備する。`dewy_setup` ロールの依存関係として自動実行される。

| ファイル | 役割 |
|---|---|
| `tasks/main.yml` | 実行タスクの定義（apt リポジトリ追加 → Docker インストール → ネットワーク・ディレクトリ作成） |
| `handlers/main.yml` | `Restart docker` ハンドラー（Docker 設定変更時にトリガー） |
| `defaults/main.yml` | デフォルト変数（`docker_version`, `three_ds_network`, `three_ds_base_dir` など） |
| `meta/main.yml` | ロールメタデータ（対応 OS: Ubuntu 22.04 / 24.04, Debian Bookworm） |

**タスクの実行順序:**
```
apt prerequisites インストール
  → /etc/apt/keyrings/ 作成
  → Docker GPG キー追加
  → Docker apt リポジトリ追加
  → docker-ce / containerd / compose plugin インストール
  → docker.service 起動・有効化
  → 3ds-net Docker ネットワーク作成
  → /opt/3ds/apps/ ディレクトリ作成
```

---

### `ansible/roles/dewy_setup/`

**種別:** Ansible ロール — Dewy バイナリ配置と systemd サービス管理

Dewy バイナリを GitHub Releases から取得して VM にインストールし、アプリごとに systemd ユニットを生成・起動する。

| ファイル | 役割 |
|---|---|
| `tasks/main.yml` | Dewy バイナリ DL・配置、アプリファイル転送、systemd ユニット生成・起動 |
| `handlers/main.yml` | `Reload systemd` ハンドラー（ユニットファイル変更時にトリガー） |
| `defaults/main.yml` | デフォルト変数（`dewy_version`, `dewy_install_dir`, `dewy_arch`, `dewy_apps`） |
| `templates/dewy.service.j2` | systemd ユニットファイルの Jinja2 テンプレート |
| `meta/main.yml` | ロールメタデータ（依存: `3ds_base`） |

**タスクの実行順序:**
```
アーキテクチャ検出 (x86_64 / arm64)
  → Dewy アーカイブ DL (/tmp/)
  → /tmp/ に展開
  → dewy バイナリを /usr/local/bin/ にコピー
  → アプリディレクトリ作成 (/opt/3ds/apps/<app>/)
  → hooks/, compose.yaml, dewy.env.example を VM に転送
  → dewy.env の存在確認（ないなら警告）
  → dewy.env を VM に転送（存在する場合のみ）
  → systemd ユニット生成 (/etc/systemd/system/dewy-<app>.service)
  → systemd daemon-reload
  → サービス起動・有効化（dewy.env が存在する場合のみ）
```

---

### `ansible/roles/dewy_setup/templates/dewy.service.j2`

**種別:** Jinja2 テンプレート — systemd ユニットファイル

`dewy_setup` ロールがアプリごとに `/etc/systemd/system/dewy-<app>.service` として展開するテンプレート。

重要な設定:
- `EnvironmentFile=` で `dewy.env` を読み込み、環境変数として Dewy に渡す
- `After=docker.service` / `Requires=docker.service` で Docker の起動後に自動開始
- `Restart=on-failure` でクラッシュ時に自動再起動

---

## `.devcontainer/devcontainer.json`

**種別:** VS Code / GitHub Codespaces 開発環境定義

このリポジトリ自体を開発・テストするためのコントリビューター向け環境。**3DS のユーザー向けではない。**

インストール予定ツール（v0.3.0 で実装）:

| ツール | 用途 |
|---|---|
| `ansible-core` / `ansible-lint` | Playbook・ロールの開発と静的解析 |
| `yamllint` | YAML ファイルの検証 |
| `shellcheck` | フックスクリプトの静的解析 |
| `docker-cli` | ローカル動作確認（デーモンはホスト側を使用） |
| `molecule` | Ansible ロールのユニットテスト |

---

## `.github/ISSUE_TEMPLATE/`

---

### `.github/ISSUE_TEMPLATE/bug_report.yaml`

**種別:** GitHub Issue テンプレート

バグ報告用。必須フィールド: バグの概要・再現手順・期待される動作・実際の動作。任意フィールド: OS・ブラウザ・Node.js バージョン・スクリーンショット。

---

### `.github/ISSUE_TEMPLATE/feature_ticket.yaml`

**種別:** GitHub Issue テンプレート（チケット駆動開発用）

機能実装チケット。作業内容・関連要件リンク・親ブランチ・作業ブランチ名・RACI 表を定義する。`dev` ブランチからの `feat/*` ブランチ運用を前提とした設計。

---

## `.gitignore`

**種別:** Git 除外設定

| パターン | 除外理由 |
|---|---|
| `.env` | 環境変数ファイル（認証情報含む可能性） |
| `dewy.env` | Dewy の実稼働設定（レジストリ認証・Slack Webhook など） |
| `backups/` | DVB が生成するバックアップアーカイブ |
| `*.tfvars` / `*.tfstate` | Terraform 機密ファイル（将来の IaC 拡張に備え） |
| OS 固有ファイル | `.DS_Store` など |

`dewy.env.example` は除外対象外のため、テンプレートとしてコミットされる。

---

## `.gitmessage`

**種別:** Git コミットメッセージテンプレート

`git commit` 時に自動的に読み込まれるテンプレート。コミットタイプと Issue 番号の記入を促す。

```
# feat | fix | docs | refactor | test | chore
<type>: <subject>

Refs: #
```

---

## `LICENSE`

MIT ライセンス。

---

## `README.md`

**種別:** プロジェクトトップレベルドキュメント

3DS の概念・機能説明・Getting Started・Blue/Green デプロイ手順・リポジトリ構成・スコープ・制限事項を網羅する。Mermaid ダイアグラムで以下を図示:

| 図 | 種類 | 内容 |
|---|---|---|
| スタック全体構成 | `graph TD` | OCI Registry → Dewy → Docker → DVB → インフラの階層構造 |
| デプロイライフサイクル | `sequenceDiagram` | ポーリングから after-hook までの一連のフロー |
| Blue/Green ワークフロー | `sequenceDiagram` | スロット切替の手順 |
