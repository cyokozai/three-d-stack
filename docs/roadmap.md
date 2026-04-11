# Roadmap — Three-D Stack (3DS)

## Milestones

| Version | Status | Focus |
|---------|--------|-------|
| v0.1.0 | ✅ Done | sample-app template, core hooks, README |
| v0.2.0 | ✅ Done | Ansible roles (3ds_base, dewy_setup), OrbStack + Proxmox verified |
| v0.3.0 | 🔲 Next | DevContainer, GitHub Actions lint CI |
| v1.0.0 | 🔲 Planned | Docs polish, Ansible Galaxy publishing |

---

## v0.3.0 — DevContainer & CI

| Task | Output |
|------|--------|
| `devcontainer.json` | ansible-core / yamllint / shellcheck / molecule |
| GitHub Actions `lint.yml` | shellcheck + yamllint + ansible-lint on PR |

---

## v1.0.0 — Public Release

| Task | Output |
|------|--------|
| `docs/backup-restore.md` | DVB backup & restore guide |
| Ansible Galaxy metadata | `ansible/galaxy.yml`, install instructions |
| CHANGELOG | v1.0.0 release notes |
