# Three-D Stack (3DS)

> **Docker · Dewy · DVB** — a portable container deployment platform for any Linux VM.

No Kubernetes. No vendor lock-in. Three well-chosen tools that work together.

| Component | Role |
|---|---|
| **[Dewy](https://github.com/linyows/dewy)** | Pull-based CD — polls OCI registry, deploys on new semver tag |
| **[Docker](https://www.docker.com/)** | Container runtime & named volume management |
| **[docker-volume-backup (DVB)](https://github.com/offen/docker-volume-backup)** | Volume snapshot & backup (optional) |

```mermaid
graph TD
    OCI["OCI Registry\n(GHCR / ECR / GAR)"]
    Dewy["Dewy\n(systemd service)\npoll & deploy"]
    App["Application Container"]
    DVB["docker-volume-backup\n(optional)"]
    Infra["Infrastructure\n(Proxmox / EC2 / VPS)"]

    OCI -->|new semver tag| Dewy
    Dewy -->|docker run| App
    Dewy -->|before-deploy-hook| DVB
    Infra -.->|node failover| Dewy
```

---

## Repository Layout

```
three-d-stack/
├── apps/
│   └── sample-app/                    # template — copy for new apps
│       ├── dewy.env.example           # Dewy config template
│       └── backup/                    # optional — only if DVB backup is needed
│           ├── hooks/
│           │   ├── before-deploy.sh   # DVB snapshot before each deploy
│           │   └── after-deploy.sh    # post-deploy tasks
│           └── compose.yaml           # DB + DVB daemon
├── core/
│   └── global-hooks/
│       ├── backup.sh                  # reusable DVB snapshot helper
│       └── notify.sh                  # reusable Slack notification helper
├── ansible/
│   ├── inventories/
│   │   ├── local/                     # OrbStack test VMs
│   │   └── proxmox/                   # Proxmox VE production
│   ├── playbooks/
│   │   ├── setup-node.yml             # bootstrap a VM
│   │   └── deploy-app.yml             # deploy / update an app
│   └── roles/
│       ├── 3ds_base/                  # Docker install, network, directory layout
│       └── dewy_setup/                # Dewy binary + systemd service per app
└── docs/
```

---

## Getting Started

### Prerequisites

- Linux VM with SSH access (Proxmox VE, EC2, VPS, OrbStack, etc.)
- Ansible on your control node
- OCI registry with **semver-tagged** images — `v0.1.0`, `v1.2.3`, etc.

> **Dewy requires semver tags.** The `latest` tag is not supported.

---

### Step 1 — Bootstrap the VM

```bash
cd ansible
ansible-playbook -i inventories/proxmox playbooks/setup-node.yml
```

Installs Docker, creates the `3ds-net` Docker network, and prepares `/opt/3ds/`.

> If Docker is already installed on the VM, the installation step is automatically skipped.

---

### Step 2 — Prepare app config on your control node

Create a directory for your app. The location is up to you — it does not need to live inside this repository.

```
/path/to/your/apps/
└── my-app/
    ├── dewy.env        ← required (never commit)
    └── secrets.env     ← optional, any name (auto-loaded into container)
```

---

### Step 3 — Deploy

```bash
ansible-playbook -i inventories/proxmox playbooks/deploy-app.yml \
  -e "dewy_apps=['my-app']" \
  -e "apps_dir=/path/to/your/apps"
```

Ansible copies config files to the VM and starts the Dewy systemd service. Once running, Dewy polls the registry and redeploys automatically on every new semver tag — no further Ansible runs needed for normal updates.

---

## Configuring `dewy.env`

`dewy.env` controls how Dewy manages the container. It is loaded by systemd as an `EnvironmentFile=`.

```bash
# ── Required ───────────────────────────────────────────────────────────────
DEWY_REGISTRY=img://ghcr.io/your-org/your-app

# Port format depends on whether the Dockerfile has an EXPOSE directive:
#   Image has EXPOSE 3000  →  DEWY_PORT=8080        (Dewy auto-maps to 3000)
#   No EXPOSE in image     →  DEWY_PORT=8080:8080   (explicit proxy:container)
DEWY_PORT=8080

# ── Optional ───────────────────────────────────────────────────────────────
DEWY_REPLICAS=1

# Health check: omit entirely for non-HTTP apps (bots, workers)
# If set, Dewy waits for HTTP 200 before switching traffic
# DEWY_HEALTH_PATH=/health

# Notifications
# DEWY_NOTIFIER=slack://your-channel?title=your-app

# Lifecycle hooks: only set if backup/ directory exists
# DEWY_BEFORE_DEPLOY_HOOK=./backup/hooks/before-deploy.sh
# DEWY_AFTER_DEPLOY_HOOK=./backup/hooks/after-deploy.sh

# Extra docker run arguments (resource limits, volume mounts, etc.)
# Do NOT add --env-file here — extra *.env files are loaded automatically
DEWY_EXTRA_ARGS="--memory 512m --cpus 1"
```

---

## Application Environment Variables

Any `*.env` file in your app directory **other than `dewy.env`** is automatically copied to the VM and passed to the container as `--env-file`. Use any filename and split secrets across multiple files as needed.

```
my-app/
├── dewy.env        ← Dewy settings (loaded by systemd, NOT passed to container)
├── db.env          ← auto-loaded into container
└── secrets.env     ← auto-loaded into container
```

```bash
# db.env
DATABASE_URL=postgres://user:pass@localhost/mydb

# secrets.env
API_KEY=xxxx
WEBHOOK_SECRET=yyyy
```

**Docker `--env-file` format rules:**
- One `KEY=VALUE` per line — no spaces around `=`
- No quotes — `KEY="value"` sets the value to `"value"` including the quotes
- Lines starting with `#` are comments

---

## App Patterns

### Web app — with HTTP health check and backup

For apps that serve HTTP and need volume backup (web apps with a database).

**Directory layout:**
```
my-app/
├── dewy.env
├── secrets.env
└── backup/
    ├── hooks/
    │   ├── before-deploy.sh   # DVB snapshot before each deploy
    │   └── after-deploy.sh    # migrations, notifications
    └── compose.yaml           # DB + DVB daemon
```

**`dewy.env`:**
```bash
DEWY_REGISTRY=img://ghcr.io/your-org/my-app
DEWY_PORT=8080
DEWY_HEALTH_PATH=/health
DEWY_REPLICAS=2
DEWY_BEFORE_DEPLOY_HOOK=./backup/hooks/before-deploy.sh
DEWY_AFTER_DEPLOY_HOOK=./backup/hooks/after-deploy.sh
DEWY_EXTRA_ARGS="-v app-data:/data --memory 512m"
```

Start the DB and DVB daemon separately on the VM:
```bash
cd /opt/3ds/apps/my-app/backup
docker compose up -d
```

---

### Non-HTTP app — bot, worker, no backup

For apps with no HTTP endpoint (Discord bots, background workers).

**Directory layout:**
```
my-bot/
├── dewy.env
└── bot.env          ← bot-specific env vars (auto-loaded)
```

**`dewy.env`:**
```bash
DEWY_REGISTRY=img://ghcr.io/your-org/my-bot

# DEWY_PORT is required by Dewy's proxy design.
# Use proxy:container format if Dockerfile has no EXPOSE directive.
# No traffic is routed here for bots.
DEWY_PORT=8080:8080

# DEWY_HEALTH_PATH must be omitted — bots have no HTTP endpoint.
# DEWY_BEFORE/AFTER_DEPLOY_HOOK must be omitted — no backup/ directory.

DEWY_REPLICAS=1
DEWY_EXTRA_ARGS="--memory 256m"
```

**`bot.env`:**
```bash
DISCORD_BOT_TOKEN=xxxx
API_KEY=yyyy
```

---

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Image has no semver tag | `no valid versioned object found` | Push `v0.1.0` — `latest` is not supported |
| `DEWY_HEALTH_PATH` set for a non-HTTP app | Deploy hangs, container never becomes healthy | Remove `DEWY_HEALTH_PATH` |
| Hook vars set without a `backup/` directory | Deploy aborted, hook script not found | Remove `DEWY_BEFORE/AFTER_DEPLOY_HOOK` |
| `DEWY_PORT=8080` with no `EXPOSE` in Dockerfile | `failed to resolve port mappings` | Use `DEWY_PORT=8080:8080` |
| Private GHCR image, no auth on VM | `401 Unauthorized` | `docker login ghcr.io` on the VM |
| Quotes in extra `*.env` files | Env var value includes literal quotes | Remove quotes — Docker `--env-file` does not strip them |
| `--env-file` in `DEWY_EXTRA_ARGS` | Redundant (still works) | Remove — extra `*.env` files are auto-loaded |

---

## Blue/Green Deployment

```bash
# Tag with build metadata to target a deployment slot
gh release create v1.2.0+green

# Run two Dewy instances, one per slot
dewy container --registry img://ghcr.io/your-org/app --slot green ...
dewy container --registry img://ghcr.io/your-org/app --slot blue  ...
```

---

## Scope

3DS is scoped to the **VM-internal layer**.

| Concern | Owner |
|---|---|
| Container deploy lifecycle | Dewy |
| Container runtime & volumes | Docker |
| Volume backup (optional) | docker-volume-backup |
| Node-level failover | Your infrastructure (Proxmox HA, ASG, etc.) |
| Secrets management | External (Vault, AWS SSM, etc.) |

---

## Limitations

- **Single-node replicas** — `--replicas N` runs N containers on one VM. Cross-node scheduling requires infrastructure-level orchestration.
- **No built-in service discovery** — put Nginx or Traefik in front.
- **No secrets management** — inject via env files or a secrets manager.

---

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgements

- [linyows/dewy](https://github.com/linyows/dewy)
- [Docker](https://www.docker.com/)
- [offen/docker-volume-backup](https://github.com/offen/docker-volume-backup)
