# Observability

## Purpose

The observability service provides short-lived platform metrics, selected
diagnostic logs, LAN-only dashboards and actionable alerts for Sprint 013.

## Responsibilities

- Alloy collects bounded host, probe, textfile and approved log data.
- Prometheus stores metrics for 15 days by default.
- Loki stores sanitized diagnostic logs for 7 days by default.
- Grafana provides declarative dashboards and owns alert evaluation.
- Host-side operation scripts publish platform and Rockstor evidence without
  giving the containers access to Docker or storage administration.

The stack does not replace Rockstor, backup evidence, security reports or
application audit logs.

## Technology

| Capability | Selection |
|---|---|
| Collector | Grafana Alloy with embedded Unix and blackbox exporters |
| Metrics | Prometheus with remote-write receiver |
| Logs | Loki single binary, TSDB index and filesystem chunks |
| Interface and alerts | Grafana OSS, LAN only |
| Configuration | Git-provisioned dashboards, datasources and rules |

All four images are supplied privately as reviewed `tag@sha256` references.

## Directory structure

```text
services/observability/
├── .env.example
├── README.md
├── compose.yaml
├── alloy/
├── grafana/
├── loki/
├── prometheus/
└── systemd/
```

Runtime state and textfile metrics remain outside the repository.

## Configuration

Copy the example without placing private values in Git:

```bash
cp services/observability/.env.example \
  ../HomeLab07.private/env/observability.env
chmod 600 ../HomeLab07.private/env/observability.env
```

Create the four runtime subdirectories under the configured observability root.
The Compose contract fixes the required numeric owners so preflight can detect
unsafe or non-writable state before deployment:

| Directory | Numeric owner |
|---|---:|
| `prometheus` | 65534 |
| `loki` | 10001 |
| `alloy` | 0 |
| `grafana` | 472 |

Review the target paths carefully, then assign only those four leaf
directories. Do not recursively change ownership of the observability root,
another share or an existing data tree.

Copy and restrict the two private inventories:

```bash
cp operation/probe-targets.example.yaml /private/path/probe-targets.yaml
cp operation/storage-metrics.example.tsv /private/path/storage-metrics.tsv
chmod 600 /private/path/probe-targets.yaml /private/path/storage-metrics.tsv
```

Replace all example endpoints, paths, aliases, image references and credentials
privately. Storage aliases must reveal neither share names nor device identity.

## Deployment

Run preflight before pulling or starting anything:

```bash
./operation/observability-preflight.sh
./operation/compose.sh observability config
./operation/start.sh observability
./operation/observability-status.sh
```

Grafana is the only service with a host mapping. It binds to the explicit LAN
address in private configuration and joins a dedicated bridge network so Docker
can apply that mapping. The internal observability network remains isolated.
Do not add an NPM proxy host, public DNS, Cloudflare route or router port
forward.

## Host metric timers

The files under `systemd/` are reviewed templates, not an automatic host
installation. Before installing them:

1. Create `/etc/homelab07/observability-runtime.env` as root with mode `600`.
2. Set only `HOMELAB07_PROJECT_ROOT` to the deployed repository root.
3. Review the service user and group against the target host.
4. Copy the units to `/etc/systemd/system/` and run `systemctl daemon-reload`.
5. Start each `.service` manually and inspect its `.prom` file.
6. Enable timers only after manual validation.

The reviewed timer templates run fixed repository scripts as root. Storage
needs this for read-only Btrfs device and scrub commands; platform collection
needs Docker inspection, whose group access is already root-equivalent. The
units retain `NoNewPrivileges`, a private temporary directory and a protected
system filesystem. Alloy remains unprivileged and reads only completed
textfiles. Reduce either unit user only after proving all required read and
write paths on the target host.

## Validation

```bash
./operation/observability-preflight.sh
./operation/platform-metrics.sh
sudo ./operation/storage-metrics.sh
./operation/observability-status.sh
./operation/security-audit.sh
```

Then validate the datasource status and the three provisioned dashboards from
an approved LAN client. Follow `docs/observability/VALIDATION.md` for alert,
retention, redaction and WAN-boundary tests.

## Backup

Prometheus samples, Loki chunks and Alloy checkpoints are disposable and are
not backed up. Grafana data is minimized and is not the configuration source of
truth. The repository and private configuration reproduce the stack.

No runtime observability root may be added silently to `operation/backup.sh`.

## Restore

1. Restore the matching repository and private configuration.
2. Recreate empty runtime directories with validated ownership.
3. Start the stack through the Operation Layer.
4. Run platform and storage collectors.
5. Confirm datasources, dashboards and rules were provisioned from Git.

Historical metrics and logs are not a restore requirement.

## Security

- Grafana is LAN-only and uses a non-wildcard host bind.
- Prometheus, Loki and Alloy publish no host ports.
- No component is privileged or mounts the Docker socket.
- Alloy receives `/proc`, `/sys`, udev data, textfiles and the explicitly
  approved NPM log directory read-only; it does not mount the host root.
- Logs are sanitized before Loki persistence and high-cardinality fields are
  not labels.
- Default credentials and mutable image references are rejected.
- Runtime storage is bounded by time and size controls.

## Related Sprint

See `sprints/SPRINT-013.md` and `docs/observability/README.md`.
