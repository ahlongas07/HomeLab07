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

1. Open **Platform Overview** to determine general health.
2. Use **Applications** to compare endpoint behavior and approved proxy logs.
3. Use **Operations** for backup, security and Rockstor freshness.
4. Follow the linked alert runbook before changing platform state.
5. Use Rockstor or the owning application for detailed diagnosis.

## Metric freshness

Every batch job publishes last run, last success and last status. Dashboards and
alerts evaluate age and status together. A prior successful value does not
prove that a scheduled operation is still running.

## Data classification

Metrics and logs are operational and restricted. They must not contain
credentials, real storage names, personal identities, filenames or private
endpoints. Detailed security evidence remains on its dedicated restricted
share, not in Prometheus or Loki.

