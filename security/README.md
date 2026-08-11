# Security Scanner Policy

This directory contains version-controlled policy for the HomeLab07 security
scanner. Runtime reports, caches, registry credentials and environment-specific
paths do not belong here.

Sprint 012 starts without vulnerability ignore rules. A future exception file
may be introduced only when each entry records a reason, owner, review date and
expiry date. Findings are not suppressed merely to make a report pass.

Gitleaks uses its embedded default rules and starts without repository ignore
entries. Full-history candidates are redacted in private reports and must be
reviewed before any scoped fingerprint exception is proposed. Broad rule or
path exclusions are prohibited.

The scanner runs in report-only mode until a target-host baseline has been
reviewed. Operational failures remain fatal even in report-only mode.
