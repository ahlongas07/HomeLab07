# SPRINT-016 — External Application Security Scan Targets

**Status:** Proposed

**Classification:** Platform Enhancement

**Phase:** Phase 2 — Shared Platform Capabilities

**Depends On:** Sprint 012 Vulnerability Management (manifest contract 1.3.0),
Sprint 013 textfile metrics

## Objective

Let the shared vulnerability management capability scan applications that run
on the platform host but are deployed from their own repositories. Each
application consumes the same pinned Trivy and Gitleaks tools, private report
share, manifest and dashboards instead of maintaining its own scanner, and its
results stay attributable to it.

## Scope

### Included

- Optional private target definitions, one file per application under
  `HomeLab07.private/env/security-scan-targets/<target-id>.env`, declaring the
  application repository root and, optionally, a Compose discovery pattern
  relative to it (default `services/*/compose.yaml`, the HomeLab07
  convention). Real paths never enter Git.
- A repository example under `operation/security-scan-targets.env.example`
  with placeholders only.
- Compose discovery inside each target on every run, so services added to a
  target repository are scanned without changing HomeLab07 or its private
  configuration.
- For each target: Trivy repository scan, Gitleaks scan of all refs and full
  history, image scan and one CycloneDX SBOM per unique image, reusing the
  existing remote and local-build (`docker save` + `--input`) paths.
- Application of the target repository's own `security/trivyignore.yaml` and
  `security/gitleaksignore` when present, under the same owner and expiry
  policy as HomeLab07 exceptions.
- Target isolation: HomeLab07 remains mandatory, while a failing external
  target is recorded as failed without blocking publication of the run.
- A runtime coverage check that compares `docker ps -a` with the declared
  inventory and reports every container whose image is not covered by
  HomeLab07 or a target.
- Manifest contract 1.4.0: every artifact records its `target` (`homelab07`
  or the target ID), target reports are stored under per-target paths, and the
  manifest records each target's status and any uncovered containers.
- Metrics, dashboards and alerts attributed by target (see below).
- Updates to `docs/security/VULNERABILITY_MANAGEMENT.md`,
  `specs/vulnerability-management.md`, the observability documentation and
  `ROADMAP.md`.

### Excluded

- Changes to target application repositories, their deployment or their
  images. Each application team owns its own exceptions and remediation.
- Running the policy audit (`operation/security-audit.sh`) against target
  applications; it remains specific to HomeLab07 services.
- Scanning containers that are not declared in a target Compose file; the
  coverage check reports them but the runtime never becomes the inventory.
- Deciding now whether uncovered containers fail the run; the check starts as
  a report and is promoted to a failure only after an owner decision.
- Blocking deployments or CI gates; the policy remains report-only.
- Separate dashboards per application.

## Target isolation

| Failure in | Run published | Run-level status | Target status |
|---|---|---|---|
| HomeLab07 (policy audit, Compose, scan, storage) | No | Failed | Not published |
| External target (missing repository, shallow clone, Compose that does not render, missing local image, expired exception, scan error) | Yes, with HomeLab07 complete | Succeeded | Failed for that target; its partial reports are discarded |

A failed target never contributes partial findings. The manifest records the
failure reason without private paths, and the target's last success
timestamp keeps the time of its previous successful scan.

## Metrics, dashboards and alerts

Metrics:

| Metric | Change |
|---|---|
| `homelab07_security_last_status`, `homelab07_security_last_success_timestamp_seconds` | Unchanged; describe the run and HomeLab07 coverage |
| `homelab07_security_target_last_status{target}`, `homelab07_security_target_last_success_timestamp_seconds{target}` | New; one series per target, including `homelab07` |
| `homelab07_security_critical_findings`, `…_high_findings`, `…_fixable_critical_findings`, `…_fixable_high_findings`, `…_gitleaks_findings` | Gain a `target` label |
| `homelab07_security_image_fixable_findings{image, severity}` | Gains a `target` label |
| `homelab07_security_uncovered_containers` | New; number of containers whose image is not declared |

A failed target publishes only its status series; its finding series are
omitted rather than reported as zero.

Dashboards:

- Operations and NAS Command Center gain a `target` variable (default
  *All*).
- *Actionable security findings* and *Security execution vs posture* show
  totals with `sum by (target)`; *Actionable security findings by image*
  filters by the selected target.
- Operations gains a per-target scan status panel and an uncovered containers
  stat.

Alerts:

- The existing batch alert remains on the run-level status.
- A new alert fires when `homelab07_security_target_last_status` is `0` for an
  external target, naming the target.
- The Gitleaks alert evaluates per target and names it.

## Requirements and acceptance criteria

- **Given** no target definitions, **when** the scan runs, **then** it
  produces the same coverage as contract 1.3.0, and every finding metric
  carries `target="homelab07"`.
- **Given** a valid target definition, **when** the scan runs, **then** the
  run contains the target's repository report, full-history Gitleaks report,
  image reports and SBOMs, all attributed to the target in the manifest,
  `image-map.json` and metrics.
- **Given** a target repository that gains a new service under its discovery
  pattern, **when** the next scan runs, **then** the new service's images are
  scanned with no HomeLab07 or private configuration change.
- **Given** a target whose Compose service uses `build:`, **when** the image
  has been built, **then** it is scanned as an exported archive and the
  manifest records its `local_image_id`.
- **Given** a failing external target, **when** the scan runs, **then** the
  run is published with complete HomeLab07 evidence, the target is marked
  failed in the manifest and its status metric, its alert fires, and none of
  its partial findings are published.
- **Given** a HomeLab07 failure, **when** the scan runs, **then** no run is
  published, exactly as in contract 1.3.0.
- **Given** a target locally built image that does not exist, **when** the
  scan runs, **then** the target fails with its own build command in the
  terminal output.
- **Given** a container whose image is not declared by HomeLab07 or any
  target, **when** preflight or scan runs, **then** the run reports it by
  container name and image and the uncovered containers metric counts it,
  without scanning it.
- **Given** the dashboards with *All* selected, **when** two targets have
  findings, **then** totals are shown per target and the per-image panel lists
  both targets' images.

## Architecture and security contracts

- Target repositories are mounted read-only into the scanners; Trivy still
  receives no Docker socket.
- A target repository must not overlap the HomeLab07 repository, the private
  configuration root, the report root or the Trivy cache.
- Target definitions contain paths only; no credentials. Target Compose files
  are rendered from their own directory with the operator's existing access.
- The coverage check reads container names and image references only; it
  does not inspect container configuration or environment.
- Detailed findings, secret metadata, real paths and image-level counts stay
  on the private report share, as for HomeLab07. Metric labels contain target
  IDs and image references only.
- Target IDs are lowercase identifiers used in report paths and metric labels;
  they must not encode private hostnames or domains.

## Validation

- `bash -n` and ShellCheck on the changed scripts; JSON validation of the
  changed dashboards; YAML validation of the alert rules.
- Preflight and scan with no targets: regression against contract 1.3.0 plus
  the `target="homelab07"` label.
- External target failure cases: missing repository, shallow clone, Compose
  file outside the target root, missing local image, expired target
  exception. Each publishes HomeLab07 evidence and marks only the target
  failed.
- Add a second Compose service to a test target repository and confirm it is
  scanned without configuration changes.
- Coverage check with one deliberately undeclared container.
- Target-host scan with one target that uses a locally built image: checksums
  validate, manifest attributes every target artifact, `local_image_id`
  matches the running container, and both dashboards show the target
  separately.

## Rollback

Remove the private target definitions to return to HomeLab07-only coverage, or
revert the scanner, dashboard and alert changes together. Completed runs remain
unchanged on the private share. Reverting the dashboards without the scanner
leaves the totals panels showing one series per target until the scanner is
reverted.

## Closure record

Record outcome, sanitized validation summary, deviations and residual work here.
Detailed private evidence remains in its approved private location.
Update the affected living specification under `/specs` before marking this
Sprint complete.
