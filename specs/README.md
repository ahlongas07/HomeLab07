# Living Capability Specifications

These documents describe the accepted behavior and boundaries of HomeLab07 as
it operates today. They are the system-level reference; Sprint files capture
proposed changes, decisions, and closure evidence.

When a Sprint changes an accepted capability, update the affected specification
in the same change. Keep detailed deployment and recovery procedures in their
service or `docs/` README, and link them here instead of copying them. Keep
target-host evidence sanitized; private reports, paths, endpoints and findings
remain outside Git.

## Capability index

| Capability | Living specification | Operational references |
|---|---|---|
| Backup and recovery | [backup.md](backup.md) | [Backup procedures](../docs/backup/README.md), [recovery manifest](../architecture/RECOVERY_MANIFEST.md), [matrix](../docs/backup/RECOVERY_MATRIX.md) |
| Observability | [observability.md](observability.md) | [Operator guide](../docs/observability/README.md), [alerts](../docs/observability/ALERTS.md), [Sprint 014 state contract](../sprints/SPRINT-014.md) |
| Vulnerability management | [vulnerability-management.md](vulnerability-management.md) | [Security operations](../docs/security/VULNERABILITY_MANAGEMENT.md), [Sprint 012](../sprints/SPRINT-012.md) |
| Identity | [identity.md](identity.md) | [Keycloak service](../services/keycloak/README.md), [Sprint 011](../sprints/SPRINT-011.md), [SPIKE-002](../sprints/SPIKE-002.md) |

Add a capability here when its accepted behavior needs a durable cross-sprint
specification. Do not create a second copy of an existing runbook solely to
populate this directory.
