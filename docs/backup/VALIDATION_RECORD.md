# Backup and Recovery Validation Record

## Purpose

Use this template to record sanitized Sprint 010 target-host evidence. Do not
record repository URLs, paths, snapshot IDs, database names, domains, usernames
or application content in Git.

## Recovery Point

| Evidence | Result |
|---|---|
| Validation date in UTC | 2026-07-31 |
| Operator-approved Restic version | Accepted by preflight and recorded in encrypted manifest |
| Preflight failures | Final validation: zero |
| Data snapshot created | Pass |
| Recovery Manifest snapshot created | Pass |
| Manifest contract version | `1.0.0` |
| Repository metadata check | Pass; all indexes, packs, snapshots, trees and blobs accepted |
| Prior runtime state restored | Pass after successful and controlled-failure paths |
| Independent-device or external copy classification | Local independent filesystem; no off-site copy |

## Disposable Restore

| Evidence | Result |
|---|---|
| Empty non-production destination used | Pass |
| Manifest schema accepted | Pass |
| Referenced data snapshot resolved | Pass |
| Artifact checksums and sizes accepted | Pass; two required artifacts |
| No production path modified | Pass |
| Measured restore duration | 38 seconds for 2.053 GiB and 74,798 entries |

## Component Validation

| Component | Required sanitized outcome | Result |
|---|---|---|
| Repository | Bundle verifies and expected revision is available | Pass |
| MariaDB | Disposable import, grants and representative queries succeed | Import passed; grant/query sampling not exercised |
| Nginx Proxy Manager | Hosts, certificates, management boundary and HTTPS route succeed | Production state migration and HTTPS passed; isolated restored runtime not exercised |
| Nextcloud | Users, shares, files, cron and representative checksums succeed | Runtime returned healthy; restored workflow not exercised |
| Paperless-ngx | Sanity check, search, original and archive download succeed | Runtime returned healthy; restored workflow not exercised |
| Jellyfin | Users, libraries, watched state, direct play and transcode succeed | Runtime returned healthy; restored workflow not exercised |
| Homebridge | Identity, accessories, automations and cameras recover in isolation | Runtime returned healthy; isolated duplicate was correctly not started |
| Stateless services | Recreate successfully without restored runtime state | Existing runtimes remained healthy; recreation not required by backup path |

## Failure and Retention

| Evidence | Result |
|---|---|
| Controlled backup failure returns non-zero | Pass; unreadable-source and missing-artifact cases rejected |
| Previously running services recover after controlled failure | Pass |
| Retention dry-run reviewed | Pass after grouping correction |
| Retention apply decision | Not applied during Sprint closure |
| Integrity check after applied retention | Not applicable; retention was not applied |

## Objectives and Decision

| Evidence | Result |
|---|---|
| Achieved manual RPO | Latest successful operator-created recovery point |
| Measured RTO | 38-second data restore; full application RTO not measured |
| Residual risks or exceptions | No off-site copy; isolated application workflows and complete RTO deferred |
| Sprint acceptance decision | Completed with owner-accepted residual risks on 2026-07-31 |

Only sanitized outcomes belong in this file. Detailed evidence remains in the
approved private operational record.
