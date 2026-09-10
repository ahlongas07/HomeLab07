# HomeLab07 Observability

Sprint 013 provides a minimum operational baseline:

```text
host + probes + operation textfiles + selected logs
                         |
                       Alloy
                      /     \
              Prometheus   Loki
                      \     /
                       Grafana
                    private LAN only
```

## Ownership boundaries

- Rockstor owns pools, shares, snapshots, SMART and storage diagnosis.
- The Operation Layer owns backup, security scanning and metric publication.
- Alloy owns collection and sanitization.
- Prometheus and Loki own disposable short-term telemetry.
- Grafana owns presentation and alert evaluation.

Observability may report a failure but must never restart, repair or modify a
monitored service.

## Operator workflow

1. Open **NAS Command Center** for the global health decision and next area.
2. Treat `Unknown` as insufficient evidence, never as healthy.
3. Use **Platform Overview** for host and storage detail.
4. Use **Applications** to compare endpoint behavior and approved proxy logs.
5. Use **Operations** for backup, security and Rockstor freshness.
6. Follow the linked alert runbook before changing platform state.
7. Use Rockstor or the owning application for detailed diagnosis.

## Metric freshness

Every batch job publishes last run, last success and last status. Dashboards and
alerts evaluate age and status together. A prior successful value does not
prove that a scheduled operation is still running.

The NAS Command Center applies the version-controlled state contract in
`sprints/SPRINT-014.md`. Confirmed critical evidence takes precedence over
missing evidence; otherwise missing or stale required evidence produces
`Unknown` before any preventive `Degraded` condition is considered.

## Data classification

Metrics and logs are operational and restricted. They must not contain
credentials, real storage names, personal identities, filenames or private
endpoints. Detailed security evidence remains on its dedicated restricted
share, not in Prometheus or Loki.
