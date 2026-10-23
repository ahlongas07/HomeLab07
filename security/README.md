# Security Scanner Policy

This directory contains version-controlled policy for the HomeLab07 security
scanner. Runtime reports, caches, registry credentials and environment-specific
paths do not belong here.

Sprint 012 started without ignore rules. Exceptions are accepted only for
reviewed false positives, and each entry records a reason, owner, review date
and expiry date. Findings are not suppressed merely to make a report pass.

| File | Scanner | Scope |
|---|---|---|
| `trivyignore.yaml` | Trivy | One rule per entry, limited to exact files or one version-specific upstream directory; native `expired_at` |
| `gitleaksignore` | Gitleaks | Exact `commit:file:rule:line` fingerprints; the scan preflight fails after an `expires:` date |

Gitleaks uses its embedded default rules. Full-history candidates are redacted
in private reports and must be reviewed before a fingerprint exception is
proposed. Broad rule or path exclusions are prohibited. Review the Trivy
entries whenever the affected image is updated: a version-specific path stops
matching after an upstream change, so the finding returns for review.

Current exceptions, reviewed on 2026-10-22:

- Upstream test fixtures and API examples detected as private keys in the
  Nginx Proxy Manager image.
- The public Azure storage emulator key in an SDK constant bundled with
  Nextcloud.
- Two Git history matches of the Valkey image reference by the generic API key
  rule.

The scanner runs in report-only mode until a target-host baseline has been
reviewed. Operational failures remain fatal even in report-only mode.
