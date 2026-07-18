# SPIKE-001 — Collaboration Platform Research Notes

**Status:** In Progress

**Phase:** Phase 1 — Documentation Review

**Reviewed On:** 2026-07-17

**Last Updated:** 2026-07-18

---

# Purpose

Capture documentation review notes for SPIKE-001.

This document records documentation findings and maps them to HomeLab07 evaluation questions.

This document does not approve implementation.

This document does not conclude that any alternative is better than OwnCloud Community.

This document is an evidence collection artifact for the future spike decision record.

The goal of this spike is not to identify the platform with the largest feature set.

The goal is to identify the platform that best aligns with HomeLab07 architectural principles while minimizing long-term operational complexity.

The spike now compares four alternatives:

- OwnCloud Community;
- oCIS;
- OpenCloud;
- Seafile.

Current notes remain intentionally non-conclusive.

OpenCloud has the deepest initial documentation review because it was the original focus of the spike.

Equivalent evidence must be collected for OwnCloud Community, oCIS, and Seafile before any recommendation is made.

---

# Sources Reviewed

Official sources:

OpenCloud:

- OpenCloud Requirements: `https://docs.opencloud.eu/docs/admin/getting-started/requirements/`
- OpenCloud Container Deployments: `https://docs.opencloud.eu/docs/admin/getting-started/container/`
- OpenCloud Docker Compose Overview: `https://docs.opencloud.eu/docs/admin/getting-started/container/docker-compose/`
- OpenCloud Behind External Proxy: `https://docs.opencloud.eu/docs/admin/getting-started/container/docker-compose/external-proxy/`
- OpenCloud Production Considerations: `https://docs.opencloud.eu/docs/next/admin/getting-started/container/docker-compose/docker-compose-production-considerations/`
- OpenCloud Volume Permissions: `https://docs.opencloud.eu/docs/admin/getting-started/container/docker-compose/docker-compose-volume-permissions/`
- OpenCloud Configuration System: `https://docs.opencloud.eu/docs/next/dev/server/configuration/config-system/`
- OpenCloud External OpenID Connect Identity Provider: `https://docs.opencloud.eu/docs/admin/configuration/authentication-and-user-management/external-idp/`
- OpenCloud Docker Hub image tags: `https://hub.docker.com/r/opencloudeu/opencloud/tags`
- OpenCloud Compose repository: `https://github.com/opencloud-eu/opencloud-compose`
- OpenCloud server image overview: `https://hub.docker.com/r/opencloudeu/opencloud`

oCIS:

- ownCloud Infinite Scale General Information: `https://doc.owncloud.com/ocis/latest/deployment/general/general-info.html`
- ownCloud Infinite Scale Server Installation with Docker Compose: `https://doc.owncloud.com/ocis/latest/admin/depl-examples/ubuntu-compose/ubuntu-compose-prod.html`
- ownCloud Infinite Scale Prerequisites: `https://doc.owncloud.com/ocis/latest/admin/prerequisites/prerequisites.html`
- ownCloud Infinite Scale `ocis init` command: `https://doc.owncloud.com/ocis/latest/deployment/general/ocis-init.html`
- ownCloud Infinite Scale architecture concepts: `https://doc.owncloud.com/ocis/latest/architecture/architecture.html`

Seafile:

- Seafile reverse proxy with non-default proxy: `https://manual.seafile.com/latest/setup/use_other_reverse_proxy/`
- Seafile HTTPS with Nginx: `https://manual.seafile.com/12.0/setup_binary/https_with_nginx/`

Platform ecosystem:

- Jellyfin Container documentation: `https://jellyfin.org/docs/general/installation/container/`
- Jellyfin Libraries documentation: `https://jellyfin.org/docs/general/server/libraries/`
- Authentik Jellyfin integration documentation: `https://docs.goauthentik.io/integrations/services/jellyfin/`

Pending official source review:

- OwnCloud Community documentation.
- Seafile Docker deployment dependencies and storage model.
- oCIS client, branding, backup, and identity documentation.

Non-official sources should not be used as decision evidence unless clearly marked as secondary context.

---

# Evidence Coverage Status

| Alternative | Current Coverage | Status |
|-------------|------------------|--------|
| OwnCloud Community | Sprint 005 implementation experience | Baseline evidence exists, formal source review pending |
| oCIS | Initial official documentation review | Partial |
| OpenCloud | Initial official documentation review | Partial but most complete |
| Seafile | Initial reverse proxy documentation review | Partial |

The current evidence is not balanced enough to support a final recommendation.

The next documentation pass must normalize coverage across all four alternatives.

---

# Common Evaluation Structure

Every evaluated platform should eventually be documented using the same structure.

This keeps the spike neutral and prevents the final recommendation from being biased by the order in which evidence was collected.

The common structure is:

- deployment model;
- Docker image and versioning;
- required dependencies;
- persistent directories;
- storage transparency;
- volume permissions;
- configuration model;
- first-run process;
- reverse proxy behavior;
- TLS and domain handling;
- authentication model;
- Windows synchronization;
- mobile clients;
- branding;
- resource usage;
- backup and restore behavior;
- exit strategy.

The OpenCloud sections below contain the most complete initial evidence because OpenCloud was reviewed first.

Equivalent sections must be added for OwnCloud Community, oCIS, and Seafile before Phase 1 can be considered complete.

---

# OpenCloud Documentation Observations

## OpenCloud Deployment Model

OpenCloud supports container deployments.

The documented Docker Compose deployment paths are:

- integrated Traefik;
- behind an external reverse proxy.

The external proxy deployment path is the relevant model for HomeLab07 because HomeLab07 already uses Nginx Proxy Manager and Cloudflare Dynamic DNS.

The OpenCloud Compose repository is modular and includes optional integrations such as:

- Collabora;
- Keycloak and LDAP;
- full text search with Apache Tika;
- monitoring;
- Radicale;
- ClamAV.

For the HomeLab07 personal lab evaluation, optional integrations should remain out of scope until the minimal service is validated.

## OpenCloud Docker Image And Versioning

The Docker Hub repository `opencloudeu/opencloud` provides versioned tags.

Observed tags during review included:

- `7.2.2`;
- `7.2`;
- `7`;
- `latest`;
- earlier `4.0.x` stable tags;
- beta and release candidate tags.

The Compose repository documents `OC_DOCKER_TAG` and shows `latest` as a default in the template.

For HomeLab07 reproducibility, the spike should avoid:

- `latest`;
- beta tags;
- release candidate tags;
- rolling tags.

The candidate image for controlled evaluation should be a specific stable patch tag, such as:

```text
opencloudeu/opencloud:<stable-patch-version>
```

The exact tag must be selected immediately before runtime evaluation.

## OpenCloud Database

OpenCloud documentation states that OpenCloud does not use a database.

It stores files on storage instead.

Implication for HomeLab07 evaluation:

- Shared MariaDB is probably not required.
- OpenCloud may reduce platform dependency count compared to OwnCloud Community.
- This must be validated during controlled deployment.

This observation does not by itself prove that OpenCloud is operationally simpler.

## oCIS Initial Observations

ownCloud Infinite Scale is the official next-generation ownCloud architecture reference.

Documentation describes it as a service-oriented architecture delivered through a single binary/container with an embedded supervisor.

Relevant documented properties:

- default external service port is `9200`;
- configuration directory defaults to `/etc/ocis`;
- base data directory defaults to `/var/lib/ocis`;
- `OCIS_CONFIG_DIR` can set the configuration directory;
- `OCIS_BASE_DATA_PATH` can set the base data directory;
- oCIS does not use a traditional database for users, groups, spaces, and internal state;
- persistent metadata and blobs are stored on filesystem paths;
- POSIX filesystem requirements are important;
- dedicated domain and reverse proxy configuration are expected for non-localhost deployments;
- the `ocis init` command creates initial configuration and can be used in Compose examples.

Implication for HomeLab07:

- oCIS should be evaluated separately from OwnCloud Community because its architecture and state model are materially different.
- oCIS may share many of the same storage and reverse proxy questions as OpenCloud.
- oCIS may be the most useful reference point for understanding OpenCloud's architectural lineage.
- oCIS memory guidance appears more demanding for production-style setups than the minimal OpenCloud requirement notes, and must be measured rather than assumed.

## Seafile Initial Observations

Seafile is the most mature evaluated alternative outside the ownCloud ecosystem.

Documentation reviewed so far confirms that Seafile can operate behind an external reverse proxy, but the current review is incomplete.

Initial implications for HomeLab07:

- Seafile must be evaluated as a distinct architecture, not as an ownCloud/oCIS/OpenCloud variant.
- Seafile storage and recovery semantics require special attention because Seafile historically manages file data in its own storage layout rather than exposing a simple normal-files tree.
- Seafile may score well on synchronization maturity, especially desktop sync, but that must be validated against HomeLab07 recovery principles.
- Seafile reverse proxy requirements must be mapped to Nginx Proxy Manager.
- Seafile dependencies must be reviewed before any runtime evaluation.

Open questions:

- What database and cache services are required by the current recommended Seafile Docker deployment?
- Can Seafile use HomeLab07 shared MariaDB, or does it require a dedicated database deployment?
- How directly recoverable are files from the NAS without Seafile application metadata?
- Does Seafile preserve the HomeLab07 requirement for simple recovery?
- How cleanly does Seafile integrate with Authentik or another future identity provider?

## OpenCloud Storage Requirements

The requirements documentation identifies storage driver constraints.

The `posix` and `decomposed` storage drivers require a fully POSIX-compliant filesystem.

The documentation also calls out atomic read-after-write consistency for directory metadata.

The `posix` driver requires extended attributes.

Implication for HomeLab07:

- NAS-backed storage must be evaluated carefully.
- The Rockstor-backed filesystem and mount options must be checked against OpenCloud storage requirements.
- Direct recoverability must be validated empirically, not assumed.
- OpenCloud storage may be simpler than OwnCloud only if the NAS mount satisfies the documented filesystem requirements.

The spike must explicitly evaluate whether OpenCloud can coexist with the current NAS data model without becoming the owner of existing NAS data.

OpenCloud should use dedicated storage for its own application state during evaluation.

Existing NAS data should be integrated only through a controlled import, synchronization, or read-only exposure mechanism unless direct use as primary OpenCloud storage is validated.

## OpenCloud Persistent Directories

Production considerations recommend mounting persistent local directories for:

```text
OC_CONFIG_DIR
OC_DATA_DIR
```

The documentation states that internal Docker volumes may be acceptable for local development or quick evaluation, but persistent host directories are recommended for production-style deployments.

Implication for HomeLab07:

- OpenCloud should use a dedicated NAS-backed storage root.
- Configuration and data should be separated.
- Example private variables should be placeholder-based.
- Real paths belong in `HomeLab07.private/`.

Candidate HomeLab07 model:

```text
${OPENCLOUD_CONFIG_ROOT} -> OC_CONFIG_DIR
${OPENCLOUD_DATA_ROOT}   -> OC_DATA_DIR
```

The exact variable names should be decided during minimal design.

## OpenCloud Volume Permissions

OpenCloud runs as a non-root user in the container.

The documentation recommends UID/GID `1000:1000` ownership for bind-mounted config and data directories.

It also recommends restrictive permissions such as:

```text
0700
```

Implication for HomeLab07:

- OpenCloud may avoid the root-owned initialization behavior observed with OwnCloud.
- Host storage permissions still require explicit validation.
- The operation layer should include a storage check if OpenCloud proceeds to controlled deployment.

## OpenCloud Configuration System

OpenCloud configuration can be provided through configuration files and environment variables.

The documented configuration location for containers is:

```text
/etc/opencloud
```

The `OC_CONFIG_DIR` environment variable can change the configuration directory.

The documented precedence model is:

1. global defaults;
2. service-specific YAML overrides;
3. environment variables.

Environment variables have the highest precedence.

Implication for HomeLab07:

- Configuration may be easier to reason about than generated PHP config files.
- The spike should validate whether environment overrides remain stable after first initialization.
- The spike should document which values are first-run only and which remain dynamic.

## OpenCloud Initial Admin Password

The Compose documentation identifies an initial admin password variable.

The OpenCloud Compose repository references:

```text
INITIAL_ADMIN_PASSWORD
```

The plain Docker guide references:

```text
IDM_ADMIN_PASSWORD
```

Implication for HomeLab07:

- The exact variable name depends on deployment path.
- The minimal Compose design must validate the correct first-run admin password variable.
- The private environment example must not hardcode credentials.

## OpenCloud Reverse Proxy

The external proxy documentation is directly relevant to HomeLab07.

OpenCloud serves traffic on port:

```text
9200
```

The documented external proxy guidance includes:

- `proxy_buffering off`;
- `proxy_request_buffering off`;
- long `proxy_read_timeout`;
- long `proxy_send_timeout`;
- increased upload body size;
- host and forwarded headers;
- timeout considerations for large uploads.

Implication for HomeLab07:

- Nginx Proxy Manager should be able to publish OpenCloud.
- NPM advanced configuration will likely be required.
- No host ports should be published if NPM is attached to the same Docker proxy network.
- The external proxy exposed compose variants must not be used unless the proxy runs on a different host.

## OpenCloud TLS And Domains

OpenCloud documentation examples assume public DNS and TLS.

Integrated Traefik handles certificates in the default path.

The external proxy path assumes TLS is handled outside OpenCloud.

Implication for HomeLab07:

- Cloudflare and Nginx Proxy Manager remain the correct publication path.
- OpenCloud should not manage TLS directly in HomeLab07.
- Real public endpoint values belong in `HomeLab07.private/`.
- Repository docs must use placeholders.

## OpenCloud Optional Collabora

External proxy documentation includes Collabora in the example.

It also notes that WOPI endpoints are served through OpenCloud paths and do not require a separate WOPI domain in the documented setup.

Implication for HomeLab07:

- Collabora should remain out of scope for minimal OpenCloud evaluation.
- Document editing should not be used as a first-pass comparison criterion.
- If evaluated later, it should be a separate phase because it adds reverse proxy and service complexity.

## OpenCloud Authentication

OpenCloud documentation references OpenID Connect and the possibility of external identity providers.

The Docker image overview states that OpenCloud authenticates users via OpenID Connect using either an external IdP or an embedded LibreGraph Connect identity provider.

OpenCloud's external IdP documentation lists requirements for OpenID Connect providers, including authorization code flow with PKCE, client discovery through WebFinger, required claims, and role assignment behavior.

Implication for HomeLab07:

- Authentication must be explicitly evaluated.
- Identity integration should remain out of scope for the minimal spike unless required for OpenCloud to function.
- Sprint 006 identity work may influence the final OpenCloud decision.
- Authentik appears conceptually compatible with the OpenCloud external IdP model because Authentik provides OpenID Connect, but this requires a dedicated validation phase.
- OpenCloud desktop and mobile clients introduce additional OIDC client discovery and client ID requirements that must be tested before adopting external identity.

## Platform And Jellyfin Compatibility

Jellyfin is not a direct collaboration platform integration target.

Jellyfin should be evaluated as an independent HomeLab07 service that may coexist with the selected collaboration platform.

Official Jellyfin container documentation supports Docker deployment with persistent config and cache directories, and bind-mounted media libraries.

Jellyfin supports multiple media library paths.

For HomeLab07, Jellyfin media libraries should be treated as application-specific media views over NAS-backed data.

Implication for the collaboration platform evaluation:

- Jellyfin and the selected collaboration platform should not share the same application-managed storage tree.
- Jellyfin media libraries should be mounted read-only unless a write workflow is explicitly approved.
- Existing NAS media data can likely remain NAS-owned and be exposed to Jellyfin as media library paths.
- The selected collaboration platform should not become the owner of Jellyfin media libraries.
- If Authentik becomes the shared identity platform, Jellyfin may integrate through plugins documented by Authentik, but this is outside the minimal collaboration platform spike.
- Compatibility should be evaluated at the platform level: shared reverse proxy, shared identity direction, separate persistence, and NAS coexistence.

## Collaboration Platform To Jellyfin Media Update Model

The most promising integration model is not direct shared application storage.

The model to evaluate is:

```text
Collaboration platform controlled upload area
    -> reviewed import or synchronization process
    -> NAS media library
    -> Jellyfin read-only media library mount
```

This model would allow the selected collaboration platform to provide a user-facing upload/update surface while keeping Jellyfin as a media playback and indexing service.

Key validation questions:

- Can each evaluated platform provide a dedicated upload area for multimedia resources?
- Can media be moved or synchronized into NAS media libraries through a controlled one-way process?
- Can Jellyfin index the updated media library after synchronization?
- Can partial uploads be kept away from Jellyfin library scans?
- Can deletions be handled safely without accidental NAS data loss?
- Can Jellyfin remain read-only against media libraries?
- Can backups clearly separate collaboration platform state, NAS media libraries, and Jellyfin config/cache?

This model should be compared against direct shared storage.

Direct shared writable storage should be treated as high risk until proven safe.

---

# Storage Transparency

Storage transparency is one of the highest-priority architectural concerns for this spike.

The purpose of this evaluation is to determine whether the application owns the data or whether the NAS remains the authoritative storage layer.

For HomeLab07, a platform that hides user data behind application-specific formats, proprietary metadata, or hard-to-recover state may be operationally risky even if the user interface is strong.

Each evaluated platform must answer the following questions:

- Are files directly accessible from the filesystem?
- Can user data be restored without the application?
- Can NAS snapshots recover user files without a complete application restore?
- Can the application be replaced without migrating the storage format?
- Does the application introduce proprietary metadata dependencies?
- Can partial recovery be performed for one user, folder, or file set?
- Which data remains useful if the database, index, or metadata store is lost?
- Which data becomes unrecoverable without application-specific metadata?
- Does the platform preserve original filenames, directory structure, timestamps, and file contents?
- Does the platform require application-managed encryption, chunking, object storage, or deduplication that affects direct recovery?

Storage transparency should receive strong influence in the final decision matrix because it directly affects disaster recovery, maintainability, and platform independence.

## OpenCloud Hardware Requirements

OpenCloud requirements list a minimal deployment for up to 10 users at roughly:

```text
1 GHz single-core
512 MB RAM
```

The same requirements page lists a medium deployment up to 1,000 users at:

```text
2 GHz dual-core
8 GB RAM
```

Implication for HomeLab07:

- The current 8 GB server is likely sufficient for a personal lab evaluation.
- Actual resource usage must still be measured during runtime testing.
- Resource observations should include idle, upload, download, and container recreation behavior.

---

# OpenCloud HomeLab07 Mapping

## Likely Reused Platform Capabilities

OpenCloud appears likely to reuse:

- Docker Compose;
- operation layer;
- Nginx Proxy Manager;
- Cloudflare Dynamic DNS;
- `homelab07-proxy`;
- NAS-backed persistent storage;
- `HomeLab07.private/`.

## Possibly Not Required

OpenCloud may not require:

- shared MariaDB;
- shared Valkey.

This must be validated.

Not requiring a service is not automatically better.

The spike must compare the reduction in dependency count against any new complexity introduced by OpenCloud.

## Platform Fit Questions Still Open

- Can OpenCloud run on `homelab07-proxy` without publishing host ports?
- Does the official Compose stack allow clean removal of Traefik while preserving required OpenCloud behavior?
- Which Compose files are needed for the minimal external proxy deployment without Collabora?
- Can HomeLab07 avoid cloning the upstream compose repository into production?
- Should HomeLab07 vendor a minimal Compose definition or reference upstream files?
- What is the cleanest way to pin the OpenCloud image and compose behavior?

---

# Initial OpenCloud Risk Register

## Storage Risk

OpenCloud storage requirements may be stricter than OwnCloud's practical NAS behavior.

The POSIX and extended attribute requirements are especially important for NAS-backed storage.

This is the highest technical risk identified during documentation review.

## Reverse Proxy Risk

External proxy configuration appears feasible but non-trivial.

Nginx Proxy Manager must support the equivalent of the documented Nginx directives for buffering, uploads, forwarded headers, and timeouts.

## Identity Risk

OpenCloud's authentication model may introduce identity requirements earlier than HomeLab07 originally planned.

This could conflict with the desire to keep the OpenCloud spike minimal.

## Upstream Compose Risk

The upstream Compose repository is modular and feature-rich.

HomeLab07 must avoid importing unnecessary complexity from upstream examples.

## Versioning Risk

The upstream Compose defaults may use floating or rolling tags.

HomeLab07 must pin versions for reproducibility.

---

# Exit Strategy

Every evaluated platform must include an exit strategy assessment.

The objective is to avoid long-term vendor, ecosystem, or platform lock-in.

The exit strategy evaluation should answer:

- How difficult is migration away from the platform?
- Can metadata be exported?
- Can permissions be migrated?
- Can users be migrated?
- Are client applications portable?
- Can HomeLab07 roll back to another platform?
- Can data be recovered without running the original application?
- Can shared links, versions, comments, tags, or activity history be exported or safely abandoned?
- Does the platform use standard protocols that reduce migration risk?
- What would a rollback plan look like after a failed controlled deployment?

A platform with an unclear exit strategy should not be recommended for adoption without explicit risk acceptance.

---

# Evidence Required Next

The following evidence is required before any decision:

- selected image and exact tag for each evaluated alternative;
- minimal Compose file set for each evaluated alternative;
- list of required environment variables for each evaluated alternative;
- persistent config and data paths for each evaluated alternative;
- storage ownership and permission validation for each evaluated alternative;
- reverse proxy configuration for Nginx Proxy Manager for each evaluated alternative;
- first-run admin login validation for each evaluated alternative;
- file upload and download validation for each evaluated alternative;
- file recoverability validation from NAS storage for each evaluated alternative;
- evidence that each evaluated alternative can coexist with existing NAS data without taking ownership of the current NAS tree;
- evaluation of controlled import, synchronization, or read-only exposure options for existing NAS data;
- evaluation of a collaboration-platform-controlled media upload area feeding NAS-backed Jellyfin media libraries;
- validation that Jellyfin can consume media libraries read-only while collaboration platform updates are handled through a controlled workflow;
- validation that partial uploads and deletions cannot corrupt the media library workflow;
- container recreation validation for each evaluated alternative;
- resource usage observation for each evaluated alternative;
- Windows synchronization validation for each evaluated alternative;
- mobile application access validation for each evaluated alternative;
- managed backup boundary validation for each evaluated alternative;
- branding feasibility validation for each evaluated alternative;
- comparison against the Sprint 005 OwnCloud Community implementation.

---

# Decision Matrix

The purpose of this matrix is not to recommend a platform yet.

Its purpose is to define the evaluation framework that will be used once all runtime evidence has been collected.

All platform score cells must remain empty until runtime validation is completed.

The Evidence column should reference the documentation section or runtime validation that justifies each future score.

| Criterion | Weight | OwnCloud Community | oCIS | OpenCloud | Seafile | Evidence |
|-----------|--------|--------------------|------|-----------|---------|----------|
| Deployment simplicity | 10% | | | | | Documentation review and minimal Compose validation |
| Operational simplicity | 15% | | | | | First-run, restart, recreation, upgrade, and operation layer validation |
| Storage transparency | 15% | | | | | Storage Transparency evaluation and filesystem recovery tests |
| Disaster recovery | 15% | | | | | Backup and restore validation |
| HomeLab07 platform integration | 10% | | | | | Network, proxy, persistence, private env, and operation layer mapping |
| Docker Compose quality | 8% | | | | | Compose readability, pinning, dependency count, and reproducibility review |
| Reverse proxy compatibility | 7% | | | | | Nginx Proxy Manager publication and header validation |
| Windows synchronization | 5% | | | | | Windows client validation |
| Mobile client quality | 5% | | | | | Mobile application validation |
| Branding feasibility | 3% | | | | | Branding reproducibility and upgrade-risk validation |
| Identity platform compatibility | 4% | | | | | Authentik or OIDC compatibility review |
| Resource consumption | 3% | | | | | Idle, upload, download, and recreation resource observations |

The total weight must equal 100%.

The proposed weights reflect HomeLab07 architectural priorities rather than feature count.

## Criterion Rationale

Deployment simplicity matters because the service must be reproducible from repository assets and private placeholders.

Operational simplicity matters because HomeLab07 should remain low-maintenance after the initial deployment succeeds.

Storage transparency matters because the NAS should remain the authoritative storage layer and recovery should not depend entirely on one application.

Disaster recovery matters because the platform must survive container recreation, storage restore, and application replacement scenarios.

HomeLab07 platform integration matters because the selected platform should reuse existing networking, proxy, persistence, and operations patterns.

Docker Compose quality matters because HomeLab07 favors declarative infrastructure over upstream stacks that are difficult to understand or trim.

Reverse proxy compatibility matters because public access must flow through Cloudflare and Nginx Proxy Manager without direct application exposure.

Windows synchronization matters because desktop sync is an MVP requirement.

Mobile client quality matters because mobile access is an MVP requirement.

Branding feasibility matters because the MVP includes customization, but branding must not dominate architectural concerns.

Identity platform compatibility matters because future Authentik integration should remain possible without redesigning the service.

Resource consumption matters because the server has finite memory and CPU, but resource efficiency is less important than recovery and operational correctness.

---

# Scoring Rules

No criterion may receive a score without supporting evidence.

Documentation review alone is insufficient where runtime validation is required.

Scores must be traceable to official documentation or empirical testing.

Unknown information must remain unscored rather than inferred.

Evidence must be sanitized before being committed.

Scores must not be based on preference, popularity, novelty, or recent implementation frustration.

When evidence conflicts, the conflict must be documented instead of resolved by assumption.

The objective is to keep the decision reproducible.

---

# Recommendation Framework

The final recommendation should classify each evaluated platform into one of the following categories:

- Recommended for Proof of Concept
- Promising but requires additional validation
- Not recommended at this time

No platform is classified in this research note.

Classification may happen only after all required documentation and runtime evidence has been collected.

The final recommendation should explain:

- which criteria drove the classification;
- which evidence supports the classification;
- which risks remain unresolved;
- whether the platform preserves HomeLab07 storage and recovery principles;
- whether the platform can be adopted without weakening platform independence;
- whether additional spike work is required before implementation.

The recommendation should prefer the platform that best aligns with HomeLab07 architectural principles, not the platform with the largest feature set.

---

# Current Non-Conclusive Status

The next phase should normalize evidence collection across OwnCloud Community, oCIS, OpenCloud, and Seafile before any runtime implementation or recommendation.
