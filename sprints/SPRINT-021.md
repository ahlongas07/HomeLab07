# SPRINT-021 — Host and Container Hardening

**Status:** Proposed

**Classification:** Platform Enhancement

**Phase:** Phase 2 — Shared Platform Capabilities

**Depends On:** Sprint 017 Caddy reverse proxy, Sprint 012 security audit,
Sprint 018 origin trust

## Objective

Close the path from a compromised container to the platform host.

Internet reaches the platform only through Cloudflare, over 80 and 443, into
Caddy and the containers it publishes. A review of the host on 2026-11-12
showed that those containers can open the host's SSH, file-sharing and NAS
management ports through the Docker bridge gateway, that SSH accepts
passwords, including for `root`, and that the host runs no firewall. A
vulnerability in any published service therefore ends one step away from the
host administration.

This Sprint makes the host configuration part of the reproducible platform:
key-only SSH, a host firewall that isolates the container bridges from host
services, a consistent container hardening baseline across every service, and
security audit checks that keep all of it verifiable.

## Scope

### Included

- `docs/security/HOST_HARDENING.md`: the expected host configuration (SSH,
  firewall zones, disabled services, Docker daemon configuration source, data
  directory permissions) with the procedure, pre-checks and rollback of each
  step. Written without addresses or host names.
- SSH: public-key authentication only and no `root` login over SSH.
- Host firewall: `firewalld` with the LAN interface in a zone that allows
  only the services the LAN uses today, and the Docker bridge interfaces in a
  zone that offers no host service. Published container ports, outbound
  traffic from containers and traffic between containers are unchanged.
- Disable `rpcbind`, which listens on every interface without an NFS server,
  and remove the orphan `/etc/docker/daemon.json`, which the NAS management
  layer does not load.
- Container hardening baseline in `compose.yaml` for the services that lack
  it: `landing-page`, `mariadb`, `keycloak`, `paperless-ngx`, `nextcloud`,
  `nextcloud-cron` and `homebridge`: `cap_drop: ALL` with the minimum
  `cap_add`, `no-new-privileges`, `read_only` with `tmpfs` where the service
  supports it, and memory and PID limits for every platform service that has
  none.
- `landing-page` runs as a non-root user with the unprivileged nginx image
  variant.
- Data root permissions: the Paperless and MariaDB data roots stop being
  world-readable.
- `operation/security-audit.sh`: new checks for the hardening baseline, the
  firewall state, the SSH authentication methods, `rpcbind`, and a runtime
  probe that confirms a container on the proxy network cannot reach host
  services.
- A new living specification `specs/platform-host.md` and updates to the
  README `Security` section of each hardened service, `CHANGELOG.md` and
  `ROADMAP.md`.

### Excluded

- NAS management interface, file sharing and mDNS exposure on the LAN: they
  stay reachable from the LAN as today; the firewall only removes them from
  the container bridges.
- `fail2ban`: SSH is LAN-only at the Internet router and becomes key-only in
  this Sprint.
- Keycloak `master` realm front-end URL and `/realms/master` public denial:
  a separate decision.
- The shared operator UID between the JuanchoAI API and the sync containers
  (accepted in Sprint 020).
- Image updates, Paperless Quote Sync deployment, new dashboards and
  observability changes.
- Services that already carry the baseline (`caddy`, `valkey`,
  `cloudflare-ddns`, `observability`, `paperless-medical-sync`,
  `paperless-quote-sync`, `jellyfin`) beyond adding missing resource limits.

## Requirements

### HH-R1 — SSH

- Password and keyboard-interactive authentication are disabled; `root`
  cannot log in over SSH. Root work continues through `su -` from the
  operator session, as today.
- Pre-check before the change: every administration device opens a session
  with its key without a password prompt; a second key is stored outside the
  host as recovery; the physical console remains the last resort and is named
  in the procedure.
- The change is applied with an open session and verified with a new one
  before the open session closes.

### HH-R2 — Host firewall

- `firewalld` is enabled and persistent across reboots.
- LAN zone: SSH, Caddy 80 and 443, the LAN administration site, Grafana,
  the NAS management interface, file sharing and mDNS. Nothing else.
- Docker bridge zone (`docker0` and every `br-*`): no host service is
  reachable from a container; Docker's own forwarding and masquerading keep
  working, so published ports, outbound traffic and inter-container traffic
  behave exactly as before. The zone configuration is reproducible from the
  procedure and survives Docker network creation.
- Rehearsal: runtime (non-permanent) rules first, with an open session; the
  probe of HH-R6 and the platform status script pass before the rules become
  permanent.

### HH-R3 — Host services and Docker daemon

- `rpcbind` socket and service are disabled.
- `/etc/docker/daemon.json` is removed and the procedure names the file the
  NAS management layer actually loads, so log and storage settings are
  changed in one place only.

### HH-R4 — Container baseline

- Every platform service declares `cap_drop: ALL`, `no-new-privileges`,
  `mem_limit` and `pids_limit`. Services whose entrypoint must start as root
  to drop privileges (`mariadb`, `paperless-ngx`, `nextcloud`,
  `nextcloud-cron`, `homebridge`) add only the capabilities that rehearsal
  proves necessary, documented per service with the reason.
- `read_only: true` with `tmpfs` for the paths the service writes, for every
  service whose image supports it; where it does not, the README records the
  reason.
- `landing-page` uses the unprivileged nginx image variant, pinned by digest,
  and serves on its unprivileged port behind Caddy.
- Limits come from observed usage on the target host plus headroom, recorded
  in each README; a limit never changes functional behavior in rehearsal.
- `homebridge` keeps host networking (`EXC-HB-HOST`); the baseline applies to
  it except where the HomeKit stack requires otherwise, documented as an
  exception.

### HH-R5 — Data root permissions

- The Paperless and MariaDB data roots are mode `750`, owned by the users the
  containers run as; the containers keep working without other changes.

### HH-R6 — Security audit

- Repository policy: every `compose.yaml` service declares the baseline of
  HH-R4; a documented exception list in the script names the services and
  the capabilities they add, and any other deviation fails.
- Runtime posture: `firewalld` active; `rpcbind` inactive; SSH offers only
  `publickey`; a disposable container on `homelab07-proxy`, from an image
  already present on the host, cannot connect to the bridge gateway on the
  SSH, file-sharing and management ports. The probe writes nothing and leaves
  no container behind.
- The audit still passes without `root` and still reports `0` failures on the
  completed configuration.

## Acceptance criteria

| ID | Scenario | Expected |
|---|---|---|
| HH-01 | SSH with the operator key from each administration device | Session opens without a password prompt |
| HH-02 | SSH with password only (`PreferredAuthentications=password`) as the operator and as `root` | Refused; the server offers `publickey` only |
| HH-03 | Probe from a disposable container on `homelab07-proxy` and on `homelab07-internal` to the bridge gateway ports 22, 139, 445, 8443 and the NAS management internal port | All connections refused |
| HH-04 | Public routes through Cloudflare, the LAN administration site and Grafana after the firewall is permanent | All answer as before; `operation/status.sh` passes |
| HH-05 | Container outbound traffic (Cloudflare DDNS update, Paperless OCR language download or an equivalent documented request) | Works |
| HH-06 | Host reboot | Firewall rules, zones and bridge assignment persist; every service returns healthy |
| HH-07 | `rpcbind` | Inactive and disabled; port 111 closed on every interface |
| HH-08 | Each hardened service after `up -d` | Healthy; its functional check from the README passes (landing page served through Caddy, MariaDB consumers connect, Keycloak login, Paperless upload and OCR, Nextcloud login and cron run, Homebridge UI and HomeKit accessory response) |
| HH-09 | `docker inspect` of every platform container | `CapDrop=[ALL]`, `no-new-privileges`, memory and PID limits set; only the documented `CapAdd` |
| HH-10 | `landing-page` | Runs as a non-root UID; read-only root file system |
| HH-11 | Data roots | Mode `750`; Paperless and MariaDB keep reading and writing |
| HH-12 | `operation/security-audit.sh` on the completed configuration | New checks pass; `0` failures; the exception list matches the compose files |
| HH-13 | `operation/backup-preflight.sh` and a backup run | Unaffected by the firewall and the permission changes |
| HH-14 | Rollback of the firewall step during rehearsal (reload without the runtime rules) | Previous behavior returns within one command, with the session still open |

## Architecture and security contracts

- No new service, network, route, host port or public exposure; the Internet
  exposure stays 80 and 443 through Cloudflare only.
- The firewall never replaces the Cloudflare source restriction in Caddy;
  both apply.
- The host configuration is documented in the repository and applied by the
  project owner as `root`; the agent prepares, rehearses and verifies but
  does not hold `root`.
- Secrets, addresses and host names stay in private configuration; the
  procedure uses placeholders and interface roles.
- The security audit remains the single place that states which services are
  exceptions and why.

## Assumptions

- Confirmed by the project owner on 2026-11-12: the Internet router forwards
  only 80 and 443 to the platform host; SSH, file sharing and the management
  interface are not reachable from the Internet.
- Observed 2026-11-12: `firewalld` is installed and inactive; the Docker
  daemon is started by the NAS management layer with its own configuration
  file; AppArmor's `docker-default` profile is active; no container mounts
  the Docker socket; private environment files are already mode `600`.
- Docker 28 registers its bridges with `firewalld` when the service is
  active; the rehearsal confirms how the management layer's Docker start
  interacts with it and the procedure records the outcome.

## Order of work

1. SSH (HH-R1), with the pre-checks, before anything that could interrupt a
   session.
2. Firewall (HH-R2) rehearsed at runtime, then made permanent; reboot test.
3. `rpcbind` and the orphan Docker file (HH-R3).
4. Container baseline (HH-R4), one service per commit, each rehearsed with
   the service's functional check.
5. Data root permissions (HH-R5).
6. Audit checks (HH-R6) and documentation, then the closure record.

## Validation

- `docker compose config` for every changed service; shell syntax check of
  the audit script; Markdown review of the new documents.
- Target-host acceptance criteria HH-01 to HH-14, with sanitized evidence in
  the closure record.

## Rollback

- SSH: restore the previous `sshd_config` from the dated backup and reload
  the service from the open session.
- Firewall: `firewall-cmd --reload` discards runtime rules; a permanent
  configuration is reverted by disabling the service, which returns the host
  to the current state.
- Host services: re-enable `rpcbind`; the removed Docker file is restored
  from Git-free backup only if a setting in it proves to be in use.
- Containers: `git revert` of the service commit and `up -d`; no data is
  touched by the baseline.
- Permissions: restore the previous mode on the data roots.

## Closure record

Record outcome, sanitized validation summary and deviations here.
Detailed private evidence remains in its approved private location.
Update the affected living specification under `/specs` before marking this
Sprint complete.
