# Discovery Interview — Three-D Stack (3DS)

_Date: 2026-04-08_

---

## Project Overview

| Item | Decision |
|------|----------|
| Project type | Infrastructure starter kit / template repository (not an application) |
| Primary deliverables | Shell scripts, Docker Compose files, Dewy config, Ansible roles, documentation |
| Target users | **Platform engineers / Infrastructure engineers** building a container deployment base |
| Distribution | GitHub (primary); Ansible Collection-like structure (planned) |
| Development | Solo / 1–2 person OSS project |

---

## Dewy Behavior (Critical Design Constraint)

Dewy is **not** a Docker Compose wrapper. It:

1. Polls an OCI registry for new semver-tagged images
2. Starts containers directly via `docker run`
3. Performs health checks before cutting over traffic

**Role separation in 3DS:**

| Component | Managed by |
|-----------|-----------|
| Application container | **Dewy** (docker run, rolling update, replicas) |
| Peripheral services (DB, Redis, DVB) | **Docker Compose** (static, long-running) |

---

## Non-Functional Requirements

| Concern | Decision |
|---------|----------|
| Target infrastructure | **Proxmox VE** (primary); OrbStack / VirtualBox / Hyper-V (local test) |
| Portability | Any SSH-accessible Linux VM — same Ansible playbook applies everywhere |
| Secrets | Injected via environment variables or external secrets manager (out of scope for 3DS) |
| Service discovery | Nginx / Traefik in front of Dewy (out of scope for 3DS) |
| Cross-node scheduling | Infrastructure layer (Proxmox HA, etc.) — not 3DS responsibility |

---

## Constraints & Decisions

- `container/Dockerfile` → **deleted** (Dewy deploys from OCI registry, not local builds)
- `container/manifest/sync/sample.yaml` → **moved to `docs/` or deleted** (manifest sub-command not adopted in core design)
- README repository layout → **superseded** by `apps/` + `core/` + `ansible/` structure
- DevContainer → **contributor-focused** (clean room for developing and testing 3DS itself)
- **VM does not need the repository cloned** — Ansible runs from the control node (local Mac) and pushes all files to the target VM via SSH. The `copy` / `template` modules handle file transfer automatically.
