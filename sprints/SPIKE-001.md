# SPIKE-001 — OpenCloud Evaluation

**Status:** Planned

**Branch:** `spike/opencloud-sprint-005-alternative`

---

# Objective

Define the technical investigation required to evaluate whether OpenCloud is a better fit than OwnCloud Community for HomeLab07.

This spike does not approve a migration.

This spike does not conclude that OpenCloud is better.

The objective is to define how HomeLab07 will validate or reject the hypothesis using objective technical evidence.

---

# Context

HomeLab07 is a personal homelab platform.

The evaluation must be performed from the perspective of a personal laboratory, not from the perspective of a company, a customer environment, or a large organization with hundreds of users.

HomeLab07 prioritizes:

- simplicity;
- reproducibility;
- low maintenance;
- Docker Compose;
- decoupled persistence;
- simple recovery;
- declarative infrastructure;
- independent services.

Sprint 005 successfully deployed OwnCloud Community as the first business-facing collaboration service.

During implementation, OwnCloud required several operational corrections around first-run state, generated configuration, storage paths, database prefixing, reverse proxy settings, and visual customization.

Those findings justify a focused technical evaluation of OpenCloud as an alternative for the same HomeLab07 collaboration use case.

---

# Motivation

The OwnCloud implementation is functional, but it introduced operational friction that may not align with the long-term goals of HomeLab07.

The evaluation is motivated by the need to determine whether OpenCloud can reduce:

- first-run fragility;
- configuration complexity;
- dependency count;
- maintenance effort;
- storage and recovery ambiguity;
- reverse proxy complexity;
- customization friction.

The motivation is not to replace OwnCloud based on preference.

The motivation is to compare both options using measurable technical evidence.

---

# Initial Hypothesis

OpenCloud could significantly simplify the HomeLab07 collaboration service architecture and operation compared to OwnCloud Community, without losing the functionality that is actually required for a personal homelab.

The spike must validate or refute this hypothesis.

---

# Hypotheses To Validate

## Architecture

- OpenCloud can run as an independent Docker Compose service within the HomeLab07 platform.
- OpenCloud requires fewer supporting services than OwnCloud Community.
- OpenCloud can avoid application-specific changes to existing platform services.

## Storage

- OpenCloud can use NAS-backed persistent storage without making the application the owner of all NAS data.
- OpenCloud preserves simple file recovery from the NAS.
- OpenCloud can keep configuration and user data separated clearly enough for backup and restore.
- OpenCloud can coexist with the current NAS data model without becoming the owner of existing NAS data.
- OpenCloud should use dedicated storage for its own application state.
- Existing NAS data should be integrated through a controlled import, synchronization, or read-only exposure mechanism, not used as primary OpenCloud storage without validation.

## Operations

- OpenCloud has a simpler first-run process than OwnCloud Community.
- OpenCloud can be started, stopped, inspected, and validated through the HomeLab07 operation layer.
- OpenCloud can be recreated without unexpected state drift.

## Publication

- OpenCloud can be published through the existing Cloudflare and Nginx Proxy Manager path.
- OpenCloud does not require direct host port exposure.
- OpenCloud handles reverse proxy headers and HTTPS detection predictably.

## Functionality

- OpenCloud supports the collaboration features actually required by HomeLab07.
- OpenCloud supports browser-based file upload and download.
- OpenCloud supports folder creation.
- OpenCloud supports basic sharing workflows.
- OpenCloud can support the future external storage direction if needed.
- OpenCloud can provide file sharing for the MVP use case.
- OpenCloud can support Windows synchronization for the MVP use case.
- OpenCloud can support mobile access for the MVP use case.
- OpenCloud can fit into a managed backup model.
- OpenCloud can support reproducible branding without introducing disproportionate operational complexity.

## Maintainability

- OpenCloud is easier to document, reproduce, and recover than OwnCloud Community for the HomeLab07 use case.
- OpenCloud introduces less operational complexity than it removes.

---

# Research Questions

## Platform Fit

- What services does OpenCloud require for a minimal HomeLab07 deployment?
- Does OpenCloud require MariaDB, Valkey, or another stateful dependency?
- Can OpenCloud run cleanly on the existing Docker network model?
- Does OpenCloud require changes to `homelab07-internal` or `homelab07-proxy`?

## Image And Versioning

- What Docker image should be evaluated?
- What image tag is appropriate for a reproducible test?
- Is a pinned version available and suitable?
- Are `latest` or release candidate images avoidable?

## Persistence

- What directories must be persisted?
- Which paths contain configuration?
- Which paths contain user data?
- Which paths are safe to back up and restore independently?
- What ownership and permission model is required on NAS-backed storage?
- Can OpenCloud coexist with the current NAS data model without becoming the owner of existing NAS data?
- Which integration mechanisms are viable for existing NAS data: controlled import, synchronization, or read-only exposure?
- What risks exist if existing NAS data is used directly as primary OpenCloud storage?

## Recovery

- Can files be recovered directly from the NAS without application-managed encryption?
- What state is required for a complete restore?
- What happens if only files are restored?
- What happens if only configuration is restored?

## Reverse Proxy

- What public URL settings are required?
- What trusted proxy settings are required?
- Are WebSocket or long-lived connection settings required?
- Does OpenCloud behave correctly behind Nginx Proxy Manager?

## Security

- Can OpenCloud run without publishing host ports?
- What authentication model is available in a minimal deployment?
- What security features are required for a personal homelab?
- Which security features should be deferred to a later identity sprint?
- Can OpenCloud integrate with a future Authentik-based OIDC identity model without requiring architecture changes?

## Platform Ecosystem

- Can OpenCloud coexist with Jellyfin as an independent HomeLab07 service?
- Can OpenCloud and Jellyfin share NAS-backed source data safely without either application becoming the owner of the other's data?
- Should media libraries remain read-only to Jellyfin and outside OpenCloud-managed storage?
- Can OpenCloud, Jellyfin, and future services share an Authentik identity layer while keeping service data independent?
- Can OpenCloud provide a controlled workflow for adding or updating multimedia resources that Jellyfin later indexes?
- What synchronization or import mechanism is safest between an OpenCloud-managed upload area and NAS-backed Jellyfin media libraries?
- Can Jellyfin refresh or rescan libraries after OpenCloud-mediated media updates without requiring manual NAS edits?

## Functionality

- Can an administrator log in after first deployment?
- Can a user upload, download, rename, move, and delete files?
- Can folders be created and shared?
- Are deleted files recoverable through the UI?
- Are files still available after container recreation?
- Can files be synchronized from Windows clients?
- Is mobile access available and usable for the personal lab MVP?
- Can the service support a managed backup workflow?

## Resource Usage

- What memory and CPU usage does OpenCloud show at idle?
- What resource usage is observed during upload and download?
- Is the resource profile simpler or lighter than OwnCloud Community for the same test workload?

## Customization

- Can branding be applied reproducibly?
- Does customization require modifying container internals?
- Does customization survive container recreation?
- Does customization introduce integrity or upgrade risks?

---

# MVP Capability Targets

The OpenCloud evaluation should validate whether the platform can support the following MVP capabilities for HomeLab07:

| Capability | Required For MVP | Evaluation Focus |
|------------|------------------|------------------|
| File sharing | Yes | Browser upload, download, folder creation, sharing workflow |
| Windows synchronization | Yes | Availability, configuration effort, reliability, recovery behavior |
| Mobile application access | Yes | Availability, login, file browsing, upload and download |
| Managed backups | Yes | Clear backup boundaries, restore procedure, NAS recoverability |
| Branding | Yes | Reproducibility, upgrade impact, operational maintenance |

Managed backups are a differentiating requirement because HomeLab07 must remain recoverable and maintainable without relying on application-specific manual recovery steps.

Branding is required for the MVP, but it must not override higher-priority concerns such as simplicity, reproducibility, and recoverability.

---

# Media Library Integration Evaluation

The spike should evaluate a possible OpenCloud and Jellyfin coexistence model for multimedia resources.

Jellyfin should be treated as the media playback and indexing service.

OpenCloud should be treated as a collaboration and controlled upload/update surface.

The evaluation must avoid a model where both applications write freely to the same application-managed storage tree.

## Candidate Model

```text
OpenCloud controlled upload area
    -> reviewed import or synchronization process
    -> NAS media library
    -> Jellyfin read-only media library mount
```

In this model:

- OpenCloud does not own the Jellyfin media library.
- Jellyfin does not write into OpenCloud-managed storage.
- The NAS remains the authoritative media storage layer.
- Media updates occur through a controlled import or synchronization workflow.
- Jellyfin indexes media after the controlled update is complete.

## Evaluation Questions

- Can OpenCloud expose a dedicated upload area for new media resources?
- Can a controlled job move or synchronize approved media into the NAS media library?
- Should synchronization be one-way only from OpenCloud upload area to NAS media library?
- Should Jellyfin media mounts be read-only by default?
- How are deletions handled without accidental data loss?
- How are partial uploads prevented from being indexed by Jellyfin?
- Can Jellyfin library scans be triggered or scheduled after updates?
- What metadata side effects does Jellyfin create, and where are they stored?
- Can backups clearly separate OpenCloud state, NAS media, and Jellyfin config/cache?

## Non-Goals

- OpenCloud must not become the primary media library database.
- Jellyfin must not become a file collaboration tool.
- The spike must not implement automatic media workflows before storage ownership is validated.
- The spike must not expose existing NAS media libraries as writable OpenCloud primary storage without validation.

---

# Scope

## In Scope

- Review OpenCloud documentation.
- Identify the recommended Docker image and versioning strategy.
- Define a minimal OpenCloud Compose deployment for HomeLab07.
- Define required private environment variables.
- Define persistent storage requirements.
- Define reverse proxy requirements.
- Define validation commands.
- Define functional UI validation.
- Compare operational complexity against the Sprint 005 OwnCloud implementation.
- Document findings in repository documentation.

---

# Exclusions

The following are out of scope for this spike:

- Production migration from OwnCloud to OpenCloud.
- Decommissioning OwnCloud.
- Customer-facing rollout.
- Identity provider integration.
- Authentik implementation.
- LDAP.
- SSO.
- Jellyfin implementation.
- Media library migration.
- High availability.
- Clustering.
- Performance tuning beyond basic resource observation.
- Backup automation implementation.
- Monitoring implementation.
- External Storage implementation.
- Object storage implementation.
- Branding implementation beyond feasibility evaluation.

---

# Methodology

## Phase 1 — Documentation Review

Review current OpenCloud documentation and identify:

- supported deployment model;
- official Docker image;
- recommended versioning approach;
- required environment variables;
- required persistent paths;
- reverse proxy requirements;
- storage and recovery guidance;
- authentication model;
- upgrade guidance.

Record sources and dates reviewed.

Do not draw conclusions during this phase.

## Phase 2 — Architecture Mapping

Map OpenCloud requirements to existing HomeLab07 capabilities:

- Docker Compose;
- operation layer;
- `homelab07-internal`;
- `homelab07-proxy`;
- Nginx Proxy Manager;
- Cloudflare Dynamic DNS;
- NAS-backed persistence;
- `HomeLab07.private/`.

Identify which existing services are reused and which are not required.

## Phase 3 — Minimal Deployment Design

Draft a minimal OpenCloud service design using placeholders only.

Define:

- service directory;
- Compose file shape;
- `.env.example` requirements;
- storage mount;
- network attachment;
- healthcheck expectations;
- operation layer integration;
- validation commands.

This phase may produce proposed files in the spike branch, but the spike must remain explicitly marked as evaluation work.

## Phase 4 — Controlled Runtime Evaluation

If implementation is approved after the planning document is reviewed, deploy OpenCloud in parallel with OwnCloud using:

- separate service name;
- separate storage root;
- separate private environment file;
- separate public endpoint placeholder;
- no shared production data.

The runtime evaluation must not modify the existing OwnCloud service.

## Phase 5 — Evidence Collection

Collect evidence for:

- first-run experience;
- container health;
- storage layout;
- file recoverability;
- reverse proxy behavior;
- upload and download workflows;
- sharing workflows;
- container recreation;
- resource usage;
- customization feasibility;
- backup and restore implications.

Evidence must be sanitized before being committed.

## Phase 6 — Decision Record

After the evidence is collected, produce a decision record that either:

- validates the hypothesis;
- refutes the hypothesis;
- or identifies unresolved questions that prevent a decision.

The decision record is not part of this initial spike document.

---

# Acceptance Criteria

This spike planning document is complete when:

- the objective is documented;
- the HomeLab07 personal lab context is explicit;
- the initial hypothesis is documented without being treated as a conclusion;
- hypotheses to validate are listed;
- research questions are listed;
- scope and exclusions are documented;
- methodology is documented;
- acceptance criteria are documented;
- expected deliverables are documented;
- risks are documented;
- an estimated timeline is documented;
- the document contains no production secrets, real public URLs, private IPs, or environment-specific values.

The spike itself is complete only after a future evidence document validates or refutes the hypothesis.

---

# Expected Deliverables

The spike should produce:

- OpenCloud documentation review notes.
- OpenCloud architecture mapping for HomeLab07.
- Proposed OpenCloud service design.
- Proposed OpenCloud validation checklist.
- Storage and recovery assessment.
- Reverse proxy assessment.
- Resource usage observation.
- Functional UI validation notes.
- Operational comparison against OwnCloud Community.
- Final technical recommendation.

The final recommendation must be evidence-based.

It must not be based only on preference or implementation frustration.

---

# Risks

## Technical Risks

- OpenCloud may require dependencies not currently present in HomeLab07.
- OpenCloud may have a storage model that does not preserve simple NAS recovery.
- OpenCloud may require a more complex reverse proxy setup than expected.
- OpenCloud may require identity components that are not yet part of HomeLab07.
- OpenCloud may not support all required collaboration workflows in the minimal deployment.

## Operational Risks

- Evaluating OpenCloud may distract from stabilizing the existing OwnCloud service.
- Running two collaboration services in parallel may create confusion if endpoints or storage roots are not clearly separated.
- A successful first-run test may hide backup, restore, upgrade, or maintenance complexity.

## Decision Risks

- The evaluation may be biased by recent OwnCloud implementation friction.
- The evaluation may overvalue simplicity and undervalue maturity.
- The evaluation may undervalue documentation quality, upgrade path, or community support.

---

# Estimated Timeline

Suggested spike duration:

```text
2 to 4 focused engineering sessions
```

Suggested breakdown:

- Session 1: documentation review and architecture mapping.
- Session 2: minimal design and validation plan.
- Session 3: optional controlled deployment.
- Session 4: evidence review and recommendation.

The timeline may be extended if OpenCloud requires identity, storage, or reverse proxy components not currently available in HomeLab07.

---

# Success Criteria

The spike succeeds if HomeLab07 can make an evidence-based decision about OpenCloud.

A successful spike may result in any of the following outcomes:

- continue with OwnCloud Community;
- replace OwnCloud with OpenCloud in a future sprint;
- keep both options documented;
- defer the decision until identity, backup, or storage requirements are clearer.

The spike must not be considered successful merely because OpenCloud appears easier or newer.

The spike must be considered successful only if the decision is supported by technical evidence aligned with HomeLab07 principles.

---

## Evaluation Principles

The purpose of this spike is not to identify the platform with the largest feature set.

The purpose is to determine which platform best aligns with the architectural principles of HomeLab07.

When evaluating alternatives, the following principles take precedence:

1. Simplicity over feature count.
2. Declarative infrastructure over manual configuration.
3. Reproducibility over convenience.
4. Low operational maintenance over advanced customization.
5. Recoverability over application complexity.
6. Platform independence over application-specific optimizations.

Additional functionality should only be considered when it does not introduce disproportionate operational complexity.

The final recommendation must be based on these principles rather than popularity, familiarity, or personal preference.

---

## Platform Independence

One of the primary goals of this spike is to evaluate whether HomeLab07 has successfully separated platform capabilities from application-specific implementation.

The investigation should answer the following questions:

- Can OpenCloud replace OwnCloud without requiring architectural changes to HomeLab07?
- Which existing platform services can be reused without modification?
- Which assumptions inside HomeLab07 currently couple the platform to OwnCloud?
- Which assumptions should become generic platform capabilities instead of application-specific implementations?
- Can future collaboration platforms be integrated using the same platform services?

The spike should evaluate not only OpenCloud itself, but also the architectural flexibility of HomeLab07.

---

## Decision Matrix

The final recommendation should evaluate both platforms using the following criteria.

| Criterion | Priority |
|-----------|----------|
| Deployment simplicity | High |
| Operational simplicity | High |
| Recovery simplicity | High |
| Docker Compose integration | High |
| Persistent storage clarity | High |
| Upgrade simplicity | High |
| Reverse proxy integration | Medium |
| Documentation quality | Medium |
| Community maturity | Medium |
| Resource consumption | Medium |
| Branding flexibility | Low |
| Advanced enterprise functionality | Low |

Higher priority criteria should have greater influence on the final recommendation than lower priority criteria.

The spike should explicitly justify how each platform performs against every criterion.

This planning document defines the evaluation matrix only.

The matrix must be completed with evidence in the future spike results or decision record, not in this planning document.

---

## Long-Term Architectural Goal

This spike is part of a broader architectural objective.

HomeLab07 should provide reusable platform capabilities that allow individual applications to be replaced without requiring changes to the underlying infrastructure.

Examples of reusable platform capabilities include:

- Reverse proxy
- DNS
- TLS certificates
- Docker networking
- Persistent storage
- Backup strategy
- Monitoring
- Operational tooling

The success of this spike is not measured solely by selecting the better application.

It is also measured by validating that HomeLab07 has achieved sufficient architectural decoupling to support future application replacement with minimal platform impact.
