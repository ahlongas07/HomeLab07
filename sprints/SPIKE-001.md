# SPIKE-001 — oCIS Architecture Validation

**Phase:** Phase 2 — Architecture Validation

**Status:** Architecture review complete; proof of concept required

**Decision date:** 2026-07-18

**Branch:** `spike/opencloud-sprint-005-alternative`

---

# Objective

Validate whether ownCloud Infinite Scale (oCIS) supports the storage and
operational architecture approved for HomeLab07.

This phase evaluates architectural compatibility only. It does not compare
features, clients, branding, OpenCloud, Seafile, or other collaboration
platforms.

The question this phase must answer is:

> Is there any architectural impediment to adopting oCIS as the logical owner
> of files while preserving the HomeLab07 storage, read-only consumption,
> backup, and administrative access model?

---

# Approved Architecture

The following decisions are inputs to this validation. They are not options to
be scored:

- The NAS remains the storage platform and physical authority for persistent
  data.
- oCIS is the logical owner of files stored in its managed tree.
- Jellyfin is a read-only consumer of selected media stored in that tree.
- Backups originate on the NAS and are transferred to Amazon S3 with AWS CLI.
- An administrator can access the filesystem as `root` for maintenance,
  recovery, and migration.
- Application-managed encryption of file contents is not part of the proposed
  design.

```text
                    HomeLab07 NAS
                          │
                 oCIS-managed POSIX tree
                    │               │
                    │               └── Jellyfin (read-only)
                    │
                    ├── Administrator root access
                    │
                    └── Backup artifact creation
                                  │
                                  ▼
                              AWS CLI
                                  │
                                  ▼
                              Amazon S3
```

The NAS is the physical storage authority. Logical ownership means that oCIS
controls application-level identities, spaces, permissions, shares, and
metadata. Root access does not override those logical invariants safely.

---

# Evidence Rules

Findings use the following evidence classes:

- **Official:** current ownCloud or AWS documentation.
- **Community:** public issue reports used only to identify PoC tests and not to
  establish supported behavior.
- **Inference:** an engineering conclusion derived from official behavior that
  must be confirmed during the PoC.

Documentation was reviewed on 2026-07-18. All product behavior must be
revalidated against the exact pinned oCIS version selected for the PoC.

---

# 1. PosixFS And Data Ownership

## Finding

PosixFS is the only documented oCIS storage driver intended for shared access
by oCIS and ordinary filesystem users or services. It therefore matches the
shape of the approved architecture better than the default private `ocis`
driver.

It is not currently a production-approved foundation. The official
documentation explicitly identifies PosixFS as experimental and states that it
should not be used in production.

## Storage Semantics

With PosixFS:

- file content remains in a directly accessible POSIX filesystem tree;
- personal spaces default to paths derived from usernames;
- project spaces default to paths derived from space identifiers;
- oCIS stores required metadata in extended attributes;
- a filesystem watcher notifies oCIS of changes made outside the application;
- the filesystem must fully support required POSIX behavior and extended
  attributes;
- `nats-js-kv` is required as the identifier cache store;
- the storage root must be writable and traversable by the oCIS runtime user or
  group.

## Current Limitations

The official PosixFS documentation identifies these limitations:

- PosixFS is experimental and not recommended for production.
- File versioning is not supported.
- Spaces are represented by directories whose names may be UUIDs rather than
  display names.
- Only `inotify` and supported GPFS notification mechanisms are documented.
- SMB, NFSv3, and several mounted filesystem arrangements are not supported.
- NFSv4.2 may work when it provides the required extended attributes.
- Post-processing such as antivirus scanning is not triggered for changes that
  bypass oCIS.
- Shared access requires a deliberate UID, GID, group, and umask design.

Rockstor uses BTRFS, which is listed as a supported local POSIX filesystem by
oCIS. This does not by itself validate the container mount, extended attribute
namespaces, watcher behavior, ownership mapping, or snapshot restore behavior.
Those remain PoC gates.

## Official Recommendation

The official storage guidance associates shared filesystem access with
PosixFS, but labels it experimental. Consequently, the documentation does not
provide an official recommendation to use this mode as a production storage
foundation for an environment such as HomeLab07.

## Conclusion

PosixFS is architecturally aligned but operationally immature. It may be used
for a controlled PoC. It must not be treated as approved for HomeLab07
production use until the experimental status and the PoC gates are resolved.

Sources:

- [PosixFS documentation](https://doc.owncloud.com/ocis/latest/admin/deployment/storage/posixfs.html)
- [oCIS filesystem prerequisites](https://doc.owncloud.com/ocis/latest/admin/prerequisites/prerequisites.html)
- [General storage considerations](https://doc.owncloud.com/ocis/latest/admin/deployment/storage/general-considerations.html)
- [Storage-users configuration](https://doc.owncloud.com/ocis/next/deployment/services/s-list/storage-users.html)

---

# 2. Changes Made Outside oCIS

## Detection Model

For a HomeLab07 BTRFS PoC, the documented watcher candidate is `inotifywait`.
The watcher observes the configured tree and causes oCIS to scan after a
configurable debounce delay. oCIS then adds or updates the metadata required in
extended attributes and propagates state used for ETag-based change discovery.

The documented configuration surface includes:

```text
STORAGE_USERS_DRIVER=posix
STORAGE_USERS_POSIX_ROOT=<managed-storage-root>
STORAGE_USERS_POSIX_WATCH_TYPE=inotifywait
STORAGE_USERS_ID_CACHE_STORE=nats-js-kv
STORAGE_USERS_POSIX_USE_SPACE_GROUPS=true
```

This is an architectural example only. Environment-specific paths belong in
`HomeLab07.private/`.

## Operation Assessment

| External operation | Expected detection | Classification | Required validation |
|---|---|---|---|
| Copy a completed file into a managed space | Watcher event followed by scan | Requires synchronization | File appears once, receives required xattrs, and becomes usable through oCIS |
| Move within the same watched tree | Move events | Requires synchronization | Identity, path, shares, and client ETags remain consistent |
| Rename within the watched tree | Move events | Requires synchronization | Rename is represented once without duplicate or lost nodes |
| Delete a file directly | Delete event | Not recommended | oCIS removes the node consistently and does not promise normal trash-bin semantics |
| Restore while oCIS is stopped | No live watcher event | Not supported without a validated reconciliation procedure | Restored files, xattrs, caches, and oCIS state converge after startup |
| Roll back the live tree underneath running oCIS | Event history and stored state can diverge | Prohibited | No PoC is required because the operation violates consistency boundaries |
| Modify oCIS-owned xattrs | Metadata corruption | Prohibited | None |

## Reindexing And Reconciliation

The reviewed documentation describes event-driven scanning after watcher
notifications. It does not document a general administrator command equivalent
to a guaranteed full `files:scan --all` reconciliation procedure for PosixFS.

Therefore:

- normal external changes must rely on an active and healthy watcher;
- a watcher outage can create a missed-event risk;
- a snapshot rollback performed while oCIS is stopped cannot be assumed to
  generate the events needed for reconciliation;
- restarting oCIS must not be assumed to perform a complete authoritative scan;
- a full rescan or rebuild procedure is an unresolved PoC requirement.

A community bug report describes high CPU usage, dropped NATS messages, and
stalled processing in a PosixFS deployment with `inotifywait`. This is not
proof of general failure, but it justifies stress testing bulk changes and
watcher recovery.

Community evidence:

- [PosixFS watcher and NATS issue](https://github.com/owncloud/ocis/issues/10825)
- [Recursive PosixFS lock-file issue](https://github.com/owncloud/ocis/issues/11093)

## Snapshot Restore Rule

A BTRFS snapshot is suitable only when it captures the complete consistent
oCIS state required by the selected deployment, including filesystem contents
and extended attributes. A data-tree-only rollback is not a complete oCIS
restore.

The service must be stopped before restoring. Configuration, system state,
metadata, file contents, and persistent stores must be restored to a mutually
consistent recovery point.

---

# 3. Read-Only Consumers

## Finding

The PosixFS design explicitly permits other users or services to access the
underlying files through the filesystem. A read-only Jellyfin mount is
therefore compatible with the intended shared-access model in principle.

No official ownCloud guidance specific to Jellyfin was found. The conclusion
is an architectural inference from the documented PosixFS shared-access model.

## Required Boundary

Jellyfin must:

- mount only the selected media subtree;
- mount that subtree read-only at the container boundary;
- store its database, cache, thumbnails, subtitles, and transcode state in its
  own persistent paths;
- never modify oCIS extended attributes;
- never rename, move, delete, or create content inside the oCIS-managed tree;
- tolerate a file disappearing or changing while a library scan is running.

Jellyfin can index ordinary readable files without understanding oCIS metadata.
Read-only traversal does not require watcher synchronization because it does
not alter the tree.

## Known Limitations And PoC Questions

- Project-space directory names may be UUIDs and unsuitable for manual library
  selection without documented mappings.
- Permissions and ACLs must allow Jellyfin to traverse directories and read
  files without granting write access.
- A file being uploaded or replaced while Jellyfin scans could be observed in
  an intermediate state. Library scans should target stable content and the
  behavior must be tested with asynchronous uploads.
- oCIS may create internal or temporary entries that Jellyfin should ignore.
- A logical oCIS delete becomes a missing media item at the next Jellyfin scan.

Community reports are not sufficient to declare this combination supported.
The PoC must validate it directly using representative files and concurrent
operations.

---

# 4. Backup Strategy

## Decision

Backing up only regular file contents is not sufficient for a complete oCIS
restore.

Official oCIS guidance requires a consistent backup of configuration, system
data, metadata, and blobs. For PosixFS specifically, required metadata is
stored in extended attributes and those attributes must be included in the
backup strategy.

## AWS CLI Constraint

`aws s3 sync <local-path> s3://<bucket>/<prefix>` transfers files as S3
objects. Its documented options do not preserve arbitrary local POSIX extended
attributes, ownership, ACLs, empty directories, or complete filesystem
semantics on a later download.

Consequently:

> Direct AWS CLI synchronization of the live PosixFS tree is a content copy,
> not a complete restorable oCIS backup.

AWS CLI may remain the approved transport to S3, but it must upload a backup
artifact that already preserves the required filesystem semantics. The exact
artifact format is deferred to the backup design and must be proven by restore
testing. It must preserve at least file contents, directory structure, extended
attributes, ownership, permissions, and any ACLs required by the deployment.

## Required Backup Sets

The PoC must identify and include:

| Backup set | Requirement |
|---|---|
| Version-controlled deployment configuration | Required from the repository |
| Private runtime configuration and secrets | Required from approved private backup handling |
| oCIS configuration data | Required |
| oCIS system data and persistent stores | Required |
| PosixFS file tree | Required |
| PosixFS extended attributes | Required |
| Ownership, permissions, and applicable ACLs | Required |
| Search index | Optional only if a documented rebuild is validated |
| Thumbnails | Optional only if regeneration is validated |
| Jellyfin state | Separate backup set; outside the oCIS restore boundary |

## Consistent Backup Procedure

The official oCIS guidance requires stopping Infinite Scale to obtain a
consistent filesystem backup. The architecture-validation procedure is:

1. Stop all writers to the managed tree.
2. Stop oCIS through the HomeLab07 operation layer.
3. Create a consistent BTRFS snapshot or backup artifact covering all required
   oCIS state and PosixFS xattrs.
4. Restart oCIS after the local recovery point is complete.
5. Transfer the immutable artifact to S3 with AWS CLI.
6. Verify checksums, retention, and restore eligibility.

Snapshot atomicity across separate BTRFS subvolumes is not assumed. If oCIS
state is split across subvolumes, the service remains stopped until all
required snapshots or artifacts are complete.

## Complete Restore Procedure

1. Stop oCIS and every writer to the managed tree.
2. Restore the pinned deployment configuration and required private values.
3. Restore configuration, system data, persistent stores, PosixFS contents,
   xattrs, ownership, permissions, and ACLs from one consistent recovery point.
4. Verify paths and runtime UID/GID mappings.
5. Start the same pinned oCIS version used to create the backup.
6. Validate spaces, permissions, shares, file access, watcher health, and
   checksums.
7. Upgrade only as a separate, subsequent operation.

Sources:

- [oCIS backup guidance](https://doc.owncloud.com/ocis/next/maintenance/b-r/backup.html)
- [oCIS restore guidance](https://doc.owncloud.com/ocis/latest/admin/maintenance/b-r/restore.html)
- [oCIS backup-set considerations](https://doc.owncloud.com/ocis/next/maintenance/b-r/backup_considerations.html)
- [AWS CLI `s3 sync` reference](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html)

---

# 5. Administrative Access Classification

Root access is a recovery capability, not a supported alternative oCIS client.
Least privilege still applies even when the administrator technically has full
filesystem access.

## Safe

- Read file contents and directory names while respecting operational privacy.
- Inspect ownership, permissions, ACLs, and extended attributes without
  modifying them.
- Calculate checksums.
- Create read-only storage snapshots using the validated consistency procedure.
- Mount or copy a stopped, immutable snapshot for forensic inspection.
- Allow a read-only consumer to traverse an explicitly approved subtree.

## Require Synchronization And PoC Validation

- Copy complete files into a managed space while the watcher is healthy.
- Move or rename files inside the same managed space.
- Restore selected files using a documented procedure.
- Perform bulk imports.
- Change POSIX ownership or group membership as part of an approved permissions
  procedure.

These operations are not approved merely because the watcher exists. They
require evidence that metadata, ETags, caches, clients, and shares converge.

## Not Recommended

- Delete files outside oCIS.
- Modify a file in place while oCIS or Jellyfin may be reading it.
- Perform large external mutations without monitoring watcher and NATS health.
- Expose the complete oCIS storage root to Jellyfin.
- Treat project-space UUID directories as a stable human-facing contract.
- Restore only regular files while omitting xattrs and persistent state.

## Prohibited

- Modify or delete oCIS-managed extended attributes.
- Write to the managed tree from Jellyfin.
- Roll back the live filesystem while oCIS is running.
- Restore data and metadata from different recovery points.
- Run concurrent backup restoration and application writes.
- Use direct `aws s3 sync` of the live tree as the sole disaster-recovery copy.
- Change internal identifiers, space mappings, or application metadata by hand.

---

# 6. Open Risks

| Risk | Impact | Probability | Mitigation | Evidence |
|---|---|---:|---|---|
| PosixFS remains experimental | High: unsupported behavior or breaking changes | High | Do not approve production adoption until status changes or HomeLab07 explicitly accepts and proves the risk | Official PosixFS documentation |
| AWS CLI content sync loses xattrs and filesystem semantics | Critical: content may survive but complete oCIS restore fails | High | Upload a filesystem-preserving artifact; perform destructive restore test | oCIS xattr requirement and AWS CLI sync behavior |
| Watcher misses events during outage or bulk mutation | High: stale or inconsistent oCIS view | Medium | Health monitoring, mutation controls, bulk-change tests, validated full reconciliation procedure | Event-driven PosixFS design; community issue reports |
| No documented general full-rescan recovery path | High: snapshot or missed events may not converge | Medium | Obtain upstream confirmation and prove a reconciliation runbook in PoC | No supported command found in reviewed official documentation |
| Snapshot restores data without matching application state | Critical: metadata, caches, and files diverge | Medium | Stop oCIS and restore all required sets from one recovery point | Official restore guidance |
| Jellyfin observes partial or transient files | Medium: failed indexing or incorrect media entries | Medium | Read-only mount, stable subtree, delayed/scheduled scans, concurrent upload test | Architectural inference requiring PoC |
| UID/GID or ACL mismatch blocks access or grants writes | High: outage or boundary violation | Medium | Declarative identity mapping and read-only container mount | Official group/umask guidance |
| Project spaces use UUID directory names | Medium: fragile library mappings and operations | High | Use documented stable personal/media subtree or explicit mapping validated in PoC | Official PosixFS limitation |
| External delete bypasses expected application workflows | Medium: loss without trash/version recovery | Medium | Deletions through oCIS only; BTRFS recovery procedure | PosixFS has no versioning; external changes bypass application flow |
| Root modifies xattrs accidentally | Critical: logical metadata corruption | Low | Read-only procedures by default; backup xattrs; prohibit manual metadata edits | Official metadata model |
| PosixFS behavior changes across upgrades | High: maintenance and migration risk | Medium | Pin versions and run upgrade/rollback tests before deployment | Experimental feature status |

---

# 7. Recommendation

## Answer

**Yes. There are currently architectural impediments to adopting the exact
proposed model as a production HomeLab07 service.**

The impediments are not that oCIS encrypts the data or that Jellyfin cannot
read ordinary files. They are:

1. The required shared-filesystem driver, PosixFS, is officially experimental
   and not recommended for production.
2. The proposed direct AWS CLI synchronization does not preserve the extended
   attributes and filesystem semantics required for a complete PosixFS/oCIS
   restore.
3. A supported, deterministic reconciliation procedure after missed watcher
   events or a stopped snapshot rollback has not been established.

The architecture is suitable for a controlled PoC if the wording is refined:

- oCIS is the sole writer and logical owner under normal operation.
- Jellyfin is a strictly read-only consumer of a limited subtree.
- root access is read-only by default and filesystem mutation is exceptional,
  classified, and procedural.
- AWS CLI transports an immutable filesystem-preserving backup artifact rather
  than synchronizing the live PosixFS tree directly.
- adoption remains blocked until a complete destructive restore succeeds and
  PosixFS risk is explicitly resolved or accepted.

This finding does not reject oCIS. It defines the evidence required before an
implementation sprint can approve it.

---

# PoC Entry Criteria

The PoC may begin only with:

- a pinned stable oCIS image;
- isolated non-production BTRFS storage;
- no existing HomeLab07 user or media data;
- validated extended attribute support through every mount layer;
- explicit container UID/GID mapping;
- Jellyfin mounted read-only to a limited test subtree;
- sanitized placeholder configuration;
- rollback and cleanup procedures.

# PoC Exit Criteria

The architecture can be reconsidered for adoption only when all of the
following pass:

- files created by oCIS remain directly readable from the NAS;
- external copy, move, rename, and delete behavior is documented with watcher
  evidence;
- watcher interruption and restart behavior is understood;
- a supported full reconciliation method is identified or its absence is
  accepted explicitly;
- BTRFS snapshot restore behavior is validated while oCIS is stopped;
- Jellyfin indexes representative media without write access;
- the backup artifact preserves xattrs, ownership, permissions, ACLs, and file
  contents;
- a clean host restores the complete oCIS instance from S3;
- restored file checksums, spaces, permissions, and shares match the source;
- an upgrade between two pinned versions preserves PosixFS data and metadata;
- no secrets, production paths, private addresses, or public domains enter the
  repository.

---

# Scope Boundaries

## In Scope

- PosixFS architectural compatibility.
- External filesystem change detection and reconciliation.
- Read-only Jellyfin access.
- NAS-to-S3 backup transport and complete restoration requirements.
- Root administrative access classification.
- Architecture risks and PoC gates.

## Out Of Scope

- Comparison with OpenCloud, Seafile, or ownCloud Classic.
- Collaboration feature evaluation.
- Client, mobile, or branding evaluation.
- Production migration or deployment.
- Identity provider implementation.
- Jellyfin implementation.
- Backup automation implementation.
- Performance tuning beyond behavior needed to validate watcher reliability.

---

# Decision Record

| Decision | Status | Rationale |
|---|---|---|
| NAS remains the physical storage platform | Approved input | HomeLab07 Storage First principle |
| oCIS is the logical owner and normal writer | Approved input | Preserves application invariants |
| PosixFS is the PoC storage candidate | Conditional | Only documented driver for shared filesystem access; experimental |
| Jellyfin consumes a limited subtree read-only | Conditional | Architecturally compatible; must be proven |
| Administrator root access remains available | Approved with controls | Recovery capability, not a parallel write interface |
| AWS CLI remains the S3 transport | Conditional | Must transport a filesystem-preserving artifact |
| Direct live-tree `aws s3 sync` is a complete backup | Rejected | Does not preserve required PosixFS metadata semantics |
| Production adoption of oCIS | Not approved | Blocked by PosixFS maturity, backup, and reconciliation evidence |

---

# Related Requirements

- `FR-002` — Persistent Storage
- `FR-007` — Configuration Management
- `FR-008` — Recovery
- `NFR-001` — Reproducibility
- `NFR-002` — Maintainability
- `NFR-003` — Reliability
- `NFR-010` — Recoverability

This phase is a Platform Enhancement and Documentation Improvement. It does not
authorize implementation or migration.
