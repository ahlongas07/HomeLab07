# SPIKE-003 — Observability Depth and NAS Command Center

**Status:** Proposed — investigation only

**Classification:** Platform Capability Investigation

**Phase:** Phase 2 — Shared Platform Capabilities

**Created:** 2026-08-18

**Depends On:** Sprint 013 — Observability & Alerting

---

## Objective

Determine the smallest safe evolution of the Sprint 013 observability baseline
that lets an operator answer within 15 seconds:

> Is the NAS healthy, and where should I investigate next?

The Spike evaluates dashboard semantics, missing evidence and collection
options. It does not approve new exporters, privileged containers, Docker
socket access, monitoring credentials, active storage operations or automated
remediation.

## Why this is a Spike

The proposal combines four different kinds of change:

1. presentation changes over metrics that already exist;
2. richer host-side read-only collection;
3. application-specific exporters and authenticated probes; and
4. active functional checks that write data or require elevated access.

Treating all four as a dashboard task would hide security, ownership and
resource trade-offs. Each proposed signal must first prove that it is
actionable, reproducible, bounded and compatible with the platform contract.

## Current baseline

Sprint 013 already provides:

- host CPU, memory, swap, filesystem and network metrics through Alloy's Unix
  exporter;
- approved HTTP, TCP and TLS probes, including latency and certificate expiry;
- expected mount, filesystem type, read-only, capacity, aggregate Btrfs device
  error, data allocation, metadata allocation and scrub freshness metrics;
- running-state metrics for the declared platform services;
- backup, security-scan, platform and Rockstor batch status and freshness;
- sanitized Nginx Proxy Manager logs;
- self-metrics from Prometheus, Loki, Alloy and Grafana datasources; and
- three provisioned dashboards with a small actionable alert baseline.

The current dashboards do not yet present that evidence as a single health
decision, and several existing metric families aggregate away detail needed
for diagnosis.

## Questions to answer

1. Which requested panels can be built correctly from existing series?
2. Which missing signals can be added through bounded, read-only host-side
   textfile collectors?
3. Which signals require credentials, Docker daemon access, block-device
   access, application-specific exporters or writes to monitored services?
4. What is the measured CPU, memory, series-cardinality and storage cost on the
   8 GiB target host?
5. Which health states are actionable and owned by an existing runbook?
6. Can the command-center summary remain correct when a collector is stale or
   a required metric is absent?

## Evaluation principles

- Prefer presentation changes before adding collection components.
- Prefer existing Alloy and Prometheus capabilities before new services.
- Prefer fixed host-side read-only adapters and atomic textfiles when elevated
  host inspection is unavoidable.
- Keep Rockstor authoritative for pools, shares, snapshots, SMART diagnosis
  and storage-changing operations.
- Keep the Operation Layer authoritative for backup, restore and security-run
  evidence.
- Treat absent or stale required evidence as unknown, never healthy. Optional
  evidence must not affect the global state unless an explicit condition is
  present.
- Keep real device paths, serial numbers, domains, client identities, share
  names and other private values outside the repository and telemetry. Map
  them privately to stable abstract aliases before publication, for example
  `device="disk1"`, `pool="primary"` or `service="cloud-primary"`.
- Do not automate balance, scrub, device replacement, restore or remediation
  from an alert.

## Proposed evaluation tracks

### Track A — Semantic correction and dashboard-only improvements

This is the lowest-risk and highest-value track.

Evaluate a **NAS Command Center** built from existing evidence with:

- overall state: `Healthy`, `Degraded`, `Critical` or `Unknown`;
- healthy approved endpoints out of expected endpoints;
- expected Rockstor mounts present;
- new Btrfs errors over a bounded window;
- latest scrub status and age;
- backup status and age;
- highest storage pressure;
- host CPU, memory and swap pressure;
- network link, negotiated speed when available, RX/TX errors, discarded
  packets, link changes, TCP retransmissions and sustained interface pressure;
- declared services not running;
- certificates approaching expiry;
- active alerts grouped by severity; and
- a small recent-critical-events view linking to specialist dashboards.

The summary state must be derived from explicit rules. It must not remain green
when a required series is absent or stale. The first useful view should render
without scrolling at the target operator resolution and support a health
decision within 15 seconds during a controlled exercise.

#### Global state algorithm

Track A must deliver a version-controlled decision matrix, not only panel
thresholds. The initial precedence is:

```text
confirmed Critical > missing required evidence > confirmed Degraded > Healthy
```

Therefore:

1. if any confirmed critical condition is active, return `Critical` even when
   another required evidence family is unknown;
2. otherwise, if required evidence is absent or stale, return `Unknown`;
3. otherwise, if any preventive condition is active, return `Degraded`;
4. otherwise, return `Healthy`.

The PoC must validate at least this initial matrix and refine thresholds only
with recorded target evidence:

| Condition | Global state |
|---|---|
| Expected pool or mount absent | `Critical` |
| New Btrfs device error | `Critical` |
| Backup failed or outside its RPO | `Critical` |
| Critical endpoint unavailable | `Critical` |
| Certificate expires in less than 7 days | `Critical` |
| Certificate expires in 7–30 days | `Degraded` |
| Memory, swap, network or storage exceeds a preventive threshold | `Degraded` |
| Required collector or evidence family is absent or stale | `Unknown` |
| Optional metric absent | No effect |
| All required evidence is current and no condition is active | `Healthy` |

No aggregate query may allow an absent series to disappear from the decision.
Thresholds and persistence intervals must be explicit in provisioned rules.

#### Required and optional evidence

The Spike must produce an inventory classifying every signal. The initial
classification is:

| Evidence family | Classification |
|---|---|
| Expected pools and mounts | Required |
| Btrfs device error counters | Required |
| Backup status, freshness and RPO | Required |
| Critical endpoint probes | Required |
| Scrub status and freshness | Required |
| Host collection freshness | Required |
| Basic SMART health | Required only after its collector is accepted and deployed |
| Detailed HTTP traffic | Optional |
| Capacity forecast | Optional |
| Per-container latency | Optional |

An optional source may raise `Degraded` or `Critical` when it reports a
confirmed condition, but its absence alone does not make the global state
`Unknown`. Promotion of a new source to required is a reviewed configuration
change with a freshness contract and runbook.

Also evaluate these semantic corrections:

- separate `scan execution` from `security posture`;
- separate `backup job succeeded`, `backup is fresh`, `repository was
  verified` and `restore was tested`;
- replace the Btrfs inode panel because a conventional fixed-inode exhaustion
  model is not an adequate primary Btrfs capacity signal; and
- distinguish cumulative device error totals from recent increases.

Network signals do not all affect global state. A down expected primary link
or a persistent increase in errors may affect it; raw traffic volume and
short-lived utilization remain diagnostic until target evidence justifies a
threshold.

### Track B — Read-only storage and operation evidence

Extend the existing atomic host-side collectors in a disposable branch or
worktree before changing production.

Candidate Btrfs evidence:

- individual persistent error classes: read, write, flush, corruption and
  generation errors;
- abstract device presence without paths, serial numbers or UUIDs;
- data, metadata and system allocation by bounded profile;
- unallocated capacity and estimated free space;
- scrub state, duration, bytes examined and corrected or uncorrectable errors;
- balance or replace activity as observation only; and
- collection status, duration and freshness for every new collector.

Candidate operation evidence:

- backup size, duration and repository verification timestamp;
- last controlled restore-test timestamp and measured duration;
- declared RPO/RTO target compared with observed evidence; and
- security coverage and severity counts with no finding identities or content.

Per-share capacity remains an investigation requirement. The Spike must
determine whether supported Rockstor facilities, Btrfs qgroups or a stable
documented Rockstor API can provide a useful value while accounting for
snapshots, reflinks and shared extents. Every candidate panel must name the
exact meaning of its value: logical file size, exclusive bytes, referenced
bytes, assigned quota or estimated physical consumption. If no value is
reliable enough, the decision record must either label it explicitly as
`apparent usage` with limitations or reject the panel with evidence.

Capacity forecasting requires at least 30 days of representative history to
begin evaluation; 60–90 days is preferred. The PoC must exclude or annotate
migration and extraordinary-load windows, suppress the date when growth is
near zero or too variable, label every result as an estimate and show daily
and weekly growth beside it.

### Track C — Observability of observability

Evaluate a dedicated drill-down using native component metrics before adding
any exporter:

- Prometheus target health, scrape errors, scrape duration, active series,
  ingestion and storage use;
- Alloy component health, forwarding errors and last successful samples;
- Loki rejected lines, ingestion, query errors and storage use;
- Grafana datasource and alert-evaluation health; and
- explicit stale-data indicators for every critical evidence family.

This track should produce alerts only for failures with a documented operator
response. It must avoid circular claims such as using only Prometheus data to
assert that Prometheus itself is healthy.

The decision record must distinguish:

- **internal monitoring**, which diagnoses the NAS while the NAS and its
  observability stack remain reachable; and
- **external monitoring**, which can detect loss of the NAS, its network path
  or the complete internal observability stack.

External monitoring is not automatically approved by this Spike. The Spike
must document the blind spot and compare a small LAN monitor, another managed
host, a private remote host and an external uptime service against privacy,
availability, maintenance and notification requirements.

### Track D — Gated exporter and functional-probe PoCs

These candidates require a separate decision after Tracks A–C:

| Candidate | Potential value | Gate before PoC |
|---|---|---|
| SMART collector | Temperature and media-health trends | Compare a bounded host-side `smartctl --json` textfile adapter with `smartctl_exporter`; no raw serial labels |
| Container metrics | CPU, memory, I/O and restart correlation | No privileged Alloy, no unrestricted Docker socket; document an alternative collection boundary |
| MariaDB exporter | Connection, buffer and query health | Dedicated least-privilege monitoring user, secret lifecycle and bounded collectors |
| Valkey exporter | Memory, clients, persistence and eviction health | Dedicated read-only monitoring contract and network isolation |
| Authenticated Nextcloud probe | Evidence beyond HTTP reachability | Synthetic account, secret ownership, rate limit and non-destructive operation |
| SMB functional probe | End-to-end share availability | Dedicated synthetic share and identity, bounded file lifecycle and cleanup proof |
| Proxy traffic metrics | HTTP rate and error trends | Redaction, controlled labels and measured Loki/Prometheus cardinality |

The current Sprint 013 prohibition on privileged observability containers and
Docker socket mounts remains in force. A candidate that cannot satisfy it must
be rejected or proposed as an explicit future architecture decision, not
silently introduced by this Spike.

The SMART comparison must evaluate both implementation and maintenance cost:

| Alternative | Advantage | Risk or cost |
|---|---|---|
| Host-side `smartctl --json` plus textfile | Small, controlled and no additional service | HomeLab07 owns parser compatibility and tests |
| `smartctl_exporter` | Broader known metric surface | Device access, another lifecycle and commonly privileged deployment |

The initial preference is the host-side adapter because the target has a small
bounded disk inventory, requires only a limited metric set and can collect at
a five-minute interval. The PoC may recommend otherwise only with measured
maintainability, security and resource evidence.

## Explicitly out of scope

- Installing or deploying a new exporter.
- Modifying `HomeLab07.private/`.
- Production dashboard replacement.
- Automatic balance, scrub, repair, restart or restore.
- Full URLs, client addresses, user agents, request IDs or users as labels.
- Monitoring based on real user credentials.
- Long-term metrics or log retention.
- Per-file, per-user or unbounded per-share telemetry.
- Public access to Grafana, Prometheus, Loki or Alloy.

## Resource and cardinality budget

The PoC must measure rather than assume its cost. Initial test bounds are:

- retain the current 15-day Prometheus and 7-day Loki baseline;
- retain existing host and probe scrape intervals unless measurements justify
  a change;
- collect slow-changing SMART and storage state no more frequently than every
  five minutes during the PoC;
- admit only bounded labels from approved inventories;
- record active-series delta, Prometheus storage growth, Loki growth, Alloy
  CPU, stack memory and collection duration before and after each track; and
- reject any source whose labels can grow with paths, users, requests, files,
  snapshots or device identities.

## PoC procedure

1. Inventory existing series and map every proposed panel to its exact source.
2. Mark each panel as `existing`, `query/rule only`, `collector extension`,
   `new exporter`, `credentialed probe` or `rejected`.
3. Implement Track A in a disposable branch with no new collection source.
4. Exercise healthy, degraded, critical, absent-data and stale-data states.
5. Measure whether an operator reaches the correct diagnosis within 15 seconds.
6. Prototype Tracks B and C individually and record resource/cardinality deltas.
7. Exercise alert normal, pending, firing and resolved states; configure an
   approved private PoC contact point and confirm both firing and recovery
   notifications through it without committing its destination or credentials.
8. Verify deduplication, maintenance silences, runbook links and absence of
   duplicate ownership between Rockstor and Grafana.
9. Evaluate Track D candidates one at a time against their security gates.
10. Produce a decision record and a focused future Sprint proposal; do not roll
   PoC configuration into production implicitly.

## Acceptance criteria

The Spike is complete when:

- every requested signal has a documented source and ownership boundary;
- the command-center state model handles healthy, degraded, critical, unknown,
  absent and stale evidence;
- the exact global-state decision matrix, precedence, thresholds and
  persistence intervals are version-controlled and tested;
- every signal is classified as required or optional;
- dashboard-only improvements are separated from new collection capabilities;
- each new collector candidate has a measured resource and cardinality cost;
- privileged, Docker socket, secret-bearing and write-capable options have an
  explicit accept/reject decision;
- storage metrics are compared with read-only host commands using sanitized
  evidence;
- security execution and security posture cannot be confused;
- backup success and restore confidence cannot be confused;
- per-share capacity semantics have an evidence-backed implementation,
  `apparent usage` label or documented rejection;
- network health and the internal-monitoring blind spot are evaluated;
- normal, pending, firing, notification receipt, recovery notification,
  deduplication, maintenance silence and runbook behavior are tested through
  an approved private PoC contact point;
- Rockstor and Grafana do not own duplicate notifications for one condition;
- capacity forecasts enforce the defined history and variability gates;
- no sensitive identity or environment-specific value enters Git; and
- the recommendation fits into one reviewable implementation Sprint.

## Expected decision

The default recommendation to test is:

1. implement the NAS Command Center and semantic corrections using existing
   metrics;
2. enrich the existing storage and operation textfile contracts;
3. add observability self-health from native metrics;
4. evaluate a bounded host-side SMART adapter;
5. defer container, database and authenticated functional probes until their
   individual security and ownership gates are satisfied.

This ordering improves operator value without weakening the architecture that
Sprint 013 already validated.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| A single green status hides unknown data | False confidence | Required-series and freshness rules; explicit `Unknown` state |
| Privileged or Docker-aware collector expands control-plane access | Host compromise path | Preserve host-side fixed wrappers; reject silent exceptions |
| SMART or device labels disclose hardware identity | Sensitive inventory in telemetry | Abstract stable aliases and private mapping |
| Proxy or application labels grow without bound | Prometheus/Loki resource exhaustion | Fixed label allowlist and measured series budget |
| Functional probes mutate real data | Operational or privacy impact | Dedicated synthetic identity and disposable target, or reject |
| Capacity forecast implies false precision | Incorrect planning decision | Minimum history, confidence rules and clearly labelled estimates |
| Duplicate Rockstor and Grafana alert ownership | Alert fatigue | One owner per condition and documented escalation path |
| Internal monitoring disappears with the NAS | Complete outage produces no local notification | Document and evaluate an independent external vantage point |

## Primary references

- [Grafana Alloy Unix exporter](https://grafana.com/docs/alloy/latest/reference/components/prometheus/prometheus.exporter.unix/)
- [Grafana Alloy cAdvisor exporter](https://grafana.com/docs/alloy/latest/reference/components/prometheus/prometheus.exporter.cadvisor/)
- [Btrfs device statistics](https://btrfs.readthedocs.io/en/latest/btrfs-device.html)
- [Btrfs scrub](https://btrfs.readthedocs.io/en/latest/btrfs-scrub.html)
- [Prometheus instrumentation practices](https://prometheus.io/docs/practices/instrumentation/)
- [Prometheus metric and label naming](https://prometheus.io/docs/practices/naming/)
- [Prometheus Community smartctl exporter](https://github.com/prometheus-community/smartctl_exporter)
- `sprints/SPRINT-013.md`
- `docs/observability/README.md`
- `docs/observability/ROCKSTOR.md`
- `docs/observability/VALIDATION.md`
