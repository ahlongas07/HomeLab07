# Backup and Recovery Validation Record

## Purpose

Use this template to record sanitized Sprint 010 target-host evidence. Do not
record repository URLs, paths, snapshot IDs, database names, domains, usernames
or application content in Git.

## Recovery Point

| Evidence | Result |
|---|---|
| Validation date in UTC | Pending |
| Operator-approved Restic version | Pending |
| Preflight failures | Pending |
| Data snapshot created | Pending |
| Recovery Manifest snapshot created | Pending |
| Manifest contract version | Pending |
| Repository metadata check | Pending |
| Prior runtime state restored | Pending |
| Independent-device or external copy classification | Pending |

## Disposable Restore

| Evidence | Result |
|---|---|
| Empty non-production destination used | Pending |
| Manifest schema accepted | Pending |
| Referenced data snapshot resolved | Pending |
| Artifact checksums and sizes accepted | Pending |
| No production path modified | Pending |
| Measured restore duration | Pending |

## Component Validation

| Component | Required sanitized outcome | Result |
|---|---|---|
| Repository | Bundle verifies and expected revision is available | Pending |
| MariaDB | Disposable import, grants and representative queries succeed | Pending |
| Nginx Proxy Manager | Hosts, certificates, management boundary and HTTPS route succeed | Pending |
| Nextcloud | Users, shares, files, cron and representative checksums succeed | Pending |
| Paperless-ngx | Sanity check, search, original and archive download succeed | Pending |
| Jellyfin | Users, libraries, watched state, direct play and transcode succeed | Pending |
| Homebridge | Identity, accessories, automations and cameras recover in isolation | Pending |
| Stateless services | Recreate successfully without restored runtime state | Pending |

## Failure and Retention

| Evidence | Result |
|---|---|
| Controlled backup failure returns non-zero | Pending |
| Previously running services recover after controlled failure | Pending |
| Retention dry-run reviewed | Pending |
| Retention apply decision | Pending |
| Integrity check after applied retention | Pending or not applied |

## Objectives and Decision

| Evidence | Result |
|---|---|
| Achieved manual RPO | Pending |
| Measured RTO | Pending |
| Residual risks or exceptions | Pending |
| Sprint acceptance decision | Pending |

Only sanitized outcomes belong in this file. Detailed evidence remains in the
approved private operational record.
