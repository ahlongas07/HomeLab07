# SPRINT-012 — Vulnerability Management

**Status:** In progress — first target-host baseline complete; remediation review pending

**Classification:** Platform Capability

**Phase:** Phase 2 — Shared Platform Capabilities

**Selected Technology:** Trivy 0.72.0 and Gitleaks 8.30.1

**Last Reviewed:** 2026-08-10

---

## Objective

Introduce a reusable, read-only vulnerability-management capability that scans
the HomeLab07 repository and every unique container image declared by the
platform, generates CycloneDX SBOMs, and writes detailed artifacts to a
restricted private report share.

## Architecture

```text
operation/security-scan.sh
  -> existing repository and Compose validation
  -> ephemeral Trivy container (no Docker socket)
  -> repository vulnerability, secret and misconfiguration scan
  -> fully redacted all-ref and full-history Git secret scan
  -> unique image inventory from Docker Compose
  -> remote-registry image scans and CycloneDX SBOMs
  -> atomic run directory on the private report share
```

Trivy is not deployed as a persistent platform service. Its vulnerability
database and analysis cache are disposable local state. Detailed reports and
SBOMs are persistent security evidence, not source code.

## Scope

### Included

- Version-and-digest-pinned ephemeral Trivy execution.
- Repository vulnerability, secret and misconfiguration scanning.
- Complete Git history secret scanning with sanitized private evidence.
- Compose rendering and the existing HomeLab07 security audit.
- Nginx Proxy Manager administration bound to a required private LAN address.
- Deduplicated image inventory across service Compose definitions.
- Remote-registry vulnerability and image-configuration scanning.
- CycloneDX JSON SBOM generation per image.
- Restricted private report-share contract and atomic publication.
- Machine-readable manifest, checksums and sanitized Markdown summary.
- Report-only severity baseline for `HIGH` and `CRITICAL` findings.

### Excluded

- Docker socket mounting.
- A continuously running Trivy server.
- Automatic deletion or modification of images and application data.
- Automatic vulnerability remediation.
- CI/CD enforcement before the first reviewed baseline.
- Scanning images that exist only in a local Docker Engine.
- Publishing detailed reports through HTTP or committing them to Git.

## Storage contract

Private configuration provides two absolute, pre-created paths:

- a local writable Trivy cache that is disposable and not backed up;
- a dedicated mounted report root that is persistent, restricted and backed
  up according to the platform recovery policy.

Each successful run is published under `runs/<UTC timestamp>/`. Work is first
written to a hidden staging directory on the same filesystem and renamed only
after all expected artifacts and checksums are complete. A failed scan leaves
no published partial run.

## Security contract

- The repository is mounted read-only into the scanner.
- The Docker socket, application volumes and private configuration roots are
  never mounted into Trivy.
- Image scans use `--image-src remote`; registry credentials are outside Git.
- Detailed secret findings remain only on the restricted report share.
- The private run summary contains counts and image aliases, never detected
  secret content, production paths, credentials or personal identities.
- Ignore rules require a documented reason, owner and expiry date; Sprint 012
  establishes no default exceptions.
- Concurrent runs are rejected to protect the shared cache and evidence.

## Report-only policy

The initial baseline does not fail because a vulnerability exists. Operational
errors, missing dependencies, an unavailable report mount, failed Compose
rendering or incomplete artifact generation do fail the command. Enforcement
thresholds may be proposed only after the baseline is reviewed and exceptions
have explicit expiry dates.

## Repository deliverables

```text
operation/security-scan.sh
operation/security-scan.env.example
security/README.md
docs/security/VULNERABILITY_MANAGEMENT.md
sprints/SPRINT-012.md
```

## Acceptance criteria

- No scanner service or host port is introduced.
- The Trivy runtime reference uses a readable patch tag and immutable registry
  manifest digest.
- The Gitleaks runtime reference uses a readable patch tag and immutable
  registry manifest digest.
- No Docker socket or production application storage is mounted.
- All service Compose files render before scanning begins.
- Every unique image reference produces one Trivy JSON report and one
  CycloneDX JSON SBOM.
- The repository produces one combined vulnerability, secret and
  misconfiguration report.
- Every Git ref and the complete history produce one sanitized Gitleaks report
  without publishing matched content to the terminal, report or repository.
- Runtime validation fails if Nginx Proxy Manager administration returns to a
  wildcard host binding.
- A manifest records the UTC run ID, Git revision, Trivy version, policy mode,
  image references and artifact names.
- SHA-256 checksums cover the completed evidence set.
- The final directory is published atomically to the configured share.
- Shell syntax, repository whitespace and existing security audit validation
  pass.
- Target-host evidence contains no secret or environment-specific value.

## Closure evidence

- Sanitized preflight output.
- Trivy runtime version and immutable runtime image identity.
- Repository and image counts.
- Finding counts by severity and class.
- SBOM and checksum counts.
- Report-share permissions and mount validation.
- One failed-run test proving partial reports are not published.
- One reviewed private summary retained on the restricted report share.

## Runtime evidence

The first complete Trivy target-host run on 2026-08-10 covered the repository and
every unique declared image, generated the expected CycloneDX SBOM set, and
passed all recorded artifact checksums. Failed attempts published no partial
run. Detailed counts, image-level findings, possible-secret classifications,
SBOMs and remediation priorities remain exclusively on the restricted private
report share.

Private review identified no HomeLab07 production or repository credential in
the scanner findings. Secret-detection rules remain enabled, and every finding
classification remains scoped to the reviewed immutable evidence.

Full-history Gitleaks execution was added after the first Trivy baseline and
requires a new private target-host run before Sprint closure.
