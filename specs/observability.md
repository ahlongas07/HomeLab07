# Observability Capability

**Status:** Baseline deployed and target validation accepted; NAS Command
Center target validation pending

## Required behavior

- Collect bounded host, approved endpoint, operation-layer and storage health
  evidence through Alloy, Prometheus and Loki, and present it in Grafana.
- Treat missing or stale required evidence as `Unknown`; never report unknown
  evidence as healthy.
- Apply the NAS Command Center precedence `Critical > Unknown > Degraded >
  Healthy` to the versioned evidence and state rules.
- Keep telemetry short-lived and operational. It is not a business record or
  backup source.
- Provide actionable alerts and runbooks without automatic remediation.

## Boundaries

Grafana is LAN-only. Prometheus, Loki and Alloy publish no host ports. The
collector has no Docker socket, privileged mode, or write access to storage.
Private targets and environment-specific identifiers remain outside Git and
telemetry.

## Operational references

- [Operator guide](../docs/observability/README.md)
- [Alert runbooks](../docs/observability/ALERTS.md)
- [Collection and validation](../docs/observability/VALIDATION.md)
- [Sprint 013 baseline](../sprints/SPRINT-013.md)
- [Sprint 014 state contract](../sprints/SPRINT-014.md)
