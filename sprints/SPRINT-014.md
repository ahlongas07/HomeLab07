# SPRINT-014 — NAS Command Center

**Status:** Implementation complete — target validation pending

**Classification:** Platform Enhancement

**Phase:** Phase 2 — Shared Platform Capabilities

**Selected Technology:** Existing Grafana and Prometheus baseline

**Depends On:** Sprint 013 and SPIKE-003 Track A

---

## Objective

Turn the existing Sprint 013 evidence into one bounded operator view that can
answer whether the NAS is healthy and identify the next diagnostic area. This
Sprint implements only the dashboard and semantic-correction portion of
SPIKE-003. It adds no collector, credential, writable probe or host privilege.

## Scope

Included:

- a provisioned NAS Command Center dashboard;
- a version-controlled global state decision;
- explicit required-evidence and freshness handling;
- Btrfs-aware capacity presentation without inode pressure as a primary
  storage signal;
- separate backup execution and freshness evidence;
- separate security-scan execution and sanitized posture evidence; and
- controlled validation for healthy, degraded, critical and unknown states.

Excluded:

- SMART, container, MariaDB or Valkey exporters;
- Docker socket or block-device access from containers;
- authenticated or write-capable functional probes;
- capacity forecasting, per-share accounting and automatic remediation; and
- public observability access.

## Global state contract

The `homelab07_nas_state` recording rule uses these values:

| Value | State | Meaning |
|---:|---|---|
| `0` | Unknown | Required evidence is absent or stale and no confirmed critical condition exists. |
| `1` | Healthy | Required evidence is current and no degraded or critical condition exists. |
| `2` | Degraded | A preventive threshold is active and evidence remains sufficient. |
| `3` | Critical | A confirmed availability, recovery, storage-integrity or urgent TLS condition exists. |

Precedence is:

```text
Critical > Unknown > Degraded > Healthy
```

Critical conditions are an invalid expected mount/filesystem, read-only
storage, a new Btrfs device error, failed or out-of-RPO backup, failed approved
endpoint, or certificate expiry within seven days.

Unknown conditions cover missing host, storage, Rockstor, scrub, backup or
probe evidence, failed/unavailable Btrfs collection, plus storage/Rockstor
collection older than 15 minutes.

Degraded conditions are 80% storage, Btrfs allocation, CPU or memory pressure;
swap more than 50% used when swap exists; a declared service not running; or a
certificate expiring in 7–30 days. An unsuccessful scrub or one older than 30
days is also degraded.

With the current evidence, removal of one target from the private probe
inventory is indistinguishable from an intentional inventory change; the
state can detect a failed declared target and absence of the complete probe
family, but cannot reconstruct a deleted declaration. Target inventory review
therefore remains part of preflight and change validation until a bounded
expected-target metric is separately approved.

Thresholds are baseline operating policy and must be changed only with target
evidence and matching runbook/validation updates.

## Architecture

Prometheus loads repository-owned recording rules from a read-only mount. The
dashboard queries the resulting state and the original bounded metrics. Alloy,
collectors, retention, networks and access controls remain unchanged.

## Validation

Static validation must include JSON/YAML parsing, Prometheus rule validation,
Compose rendering and repository checks. Target validation must exercise all
four state values by changing only disposable test evidence, confirm the
precedence matrix and measure whether the operator reaches the correct next
diagnostic area within 15 seconds.

The Sprint is not complete until the target-host exercise and clean recreation
are recorded without private values in Git.

## Rollback

Revert the dashboard, recording-rule mount, rule file and related documentation,
then recreate only the observability stack. Rollback must not remove runtime
telemetry or affect monitored services.
