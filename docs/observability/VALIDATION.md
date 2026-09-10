# Observability Validation

## Accepted baseline

The platform owner and engineering team accepted the Sprint 013 target
baseline on 2026-08-15. The deployed stack produced current Grafana dashboard
evidence for backup, vulnerability scanning, operation age and Btrfs device
errors; Prometheus received the approved host, probe, operation and storage
metrics; and Loki received approved redacted reverse-proxy logs.

The validation also confirmed that root-owned operation runs publish textfile
metrics with the stable `0644` reader contract required by Alloy. Private
addresses, paths, identities, screenshots and detailed security evidence are
retained outside the repository.

External notification delivery remains an accepted residual item until a
private Grafana contact point is configured and exercised. The repository
baseline therefore guarantees local alert evaluation and runbooks, but does
not claim external delivery validation.

## Static checks

```bash
bash -n operation/observability-*.sh operation/*-metrics.sh
./operation/compose.sh observability config
git diff --check
```

Validate all JSON dashboards with `jq empty` and all YAML with an available
parser. Run Alloy, Prometheus and Loki native configuration checks using the
exact pinned target images before deployment.

## Runtime checks

```bash
./operation/observability-preflight.sh
./operation/start.sh observability
./operation/observability-status.sh
./operation/security-audit.sh
```

Required evidence:

- Grafana is bound to the explicit LAN address.
- Prometheus, Loki and Alloy have no host port.
- no container is privileged or mounts the Docker socket;
- all datasources are healthy;
- all four dashboards, including the NAS Command Center, are provisioned after
  clean recreation;
- Prometheus receives host, probe and four textfile metric sets;
- Loki contains only approved NPM files and sanitized content.

For a controlled NPM request containing a host, path, query value and test IPv4
address, confirm the newly ingested Loki line preserves the HTTP method while
replacing the request scheme, host and complete URI with `[REDACTED_TARGET]`.
Other sensitive values and IPv4 addresses must appear as `[REDACTED]` and
`[REDACTED_IP]`. The line must contain no original hostname, path, query value,
literal `${1}`/`${2}` placeholders or partially visible IPv4 octets.

## Textfile tests

1. Run platform and storage collectors.
2. Confirm every published `.prom` file has mode `0644` regardless of whether
   its producer ran as the normal operator or through a root-owned timer.
3. Confirm every file has last-run, last-success and last-status where
   applicable.
4. Interrupt a temporary test writer before rename.
5. Confirm the previous final file and samples remain intact.
6. Stop the timer beyond its maximum age and confirm stale alert behavior.
7. Remove a metric from a disposable test target and confirm no-data is not OK.

## Rockstor tests

In a controlled non-production test path:

1. Compare metrics with `findmnt`, `df` and read-only Btrfs commands.
2. Demonstrate that a directory without the expected mount returns mount `0`.
3. Confirm no writer starts against the unmounted path.
4. Verify abstract labels reveal no real path or device identity.

## Access boundary

From an approved LAN client, connect to the configured Grafana address. From a
network outside the LAN, confirm the port is denied. Confirm no router forward,
public DNS record, proxy host or Cloudflare route exists.

## Alert tests

Exercise one target from each class safely:

- endpoint down and resolved;
- stale or failed batch metric;
- missing test mount;
- critical test capacity series;
- certificate threshold.

Record pending, firing and resolved states. Notification delivery remains
incomplete until a private contact point is configured and tested.

## NAS Command Center state tests

Use only a disposable test target or temporary test-series source. Never alter
production storage, backup evidence or certificates to manufacture a state.

1. Validate `Healthy` (`1`) with every required family current and no active
   condition.
2. Cross one preventive threshold and validate `Degraded` (`2`).
3. Remove one required test family, then age one required timestamp, and
   validate `Unknown` (`0`) in both cases.
4. Activate a safe critical test condition and validate `Critical` (`3`).
5. Combine missing evidence with a confirmed critical condition and confirm
   that `Critical` wins.
6. Confirm recovery returns through pending/resolved behavior to `Healthy`.
7. Ask an operator who did not prepare the fault to identify the correct next
   dashboard or runbook within 15 seconds.
8. Record sanitized results and query timestamps; do not commit endpoints,
   paths, storage names, screenshots or contact-point details.

## Rollback

```bash
./operation/stop.sh observability
```

Confirm monitored applications and operations remain healthy. Do not delete
runtime roots as part of rollback. Their removal is a separate reviewed action.
