# SPIKE-001 — Collaboration Platform Alternatives Evaluation

**Status:** Planned

**Branch:** `spike/opencloud-sprint-005-alternative`

---

# Objective

Define the technical investigation required to compare collaboration platform alternatives for HomeLab07.

The alternatives under evaluation are:

- OwnCloud Community as the Sprint 005 baseline.
- ownCloud Infinite Scale, also known as oCIS, as the official new architecture reference.
- OpenCloud as the community evolution of that architecture.
- Seafile as the most consolidated alternative outside the ownCloud ecosystem.

| Alternative | Role In Evaluation |
|-------------|--------------------|
| OwnCloud Community | Baseline implemented during Sprint 005 |
| oCIS | Official next-generation ownCloud architecture reference |
| OpenCloud | Community evolution of the oCIS-style architecture |
| Seafile | Mature non-ownCloud ecosystem alternative |

This spike does not approve a migration.

This spike does not conclude that any alternative is better.

The objective is to define how HomeLab07 will compare the alternatives using objective technical evidence.

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

Those findings justify a focused technical evaluation of multiple collaboration platform alternatives for the same HomeLab07 use case.

---

# Motivation

The OwnCloud implementation is functional, but it introduced operational friction that may not align with the long-term goals of HomeLab07.

The evaluation is motivated by the need to determine whether another platform can reduce:

- first-run fragility;
- configuration complexity;
- dependency count;
- maintenance effort;
- storage and recovery ambiguity;
- reverse proxy complexity;
- customization friction.

The motivation is not to replace OwnCloud based on preference.

The motivation is to compare all evaluated options using measurable technical evidence.

---

# Initial Hypothesis

At least one alternative to OwnCloud Community could significantly simplify the HomeLab07 collaboration service architecture and operation without losing the functionality that is actually required for a personal homelab.

The spike must validate or refute this hypothesis.

---

# Hypotheses To Validate

## Architecture

- Each alternative can be evaluated as an independent Docker Compose service within the HomeLab07 platform.
- One or more alternatives may require fewer supporting services than OwnCloud Community.
- The selected alternative can avoid application-specific changes to existing platform services.

## Storage

- The selected platform can use NAS-backed persistent storage without making the application the owner of all NAS data.
- The selected platform preserves simple file recovery from the NAS.
- The selected platform can keep configuration and user data separated clearly enough for backup and restore.
- The selected platform can coexist with the current NAS data model without becoming the owner of existing NAS data.
- Each evaluated platform should use dedicated storage for its own application state during testing.
- Existing NAS data should be integrated through a controlled import, synchronization, or read-only exposure mechanism, not used as primary collaboration platform storage without validation.

## Operations

- One or more alternatives may have a simpler first-run process than OwnCloud Community.
- Each evaluated platform can be started, stopped, inspected, and validated through the HomeLab07 operation layer.
- The selected platform can be recreated without unexpected state drift.

## Publication

- Each evaluated platform can be published through the existing Cloudflare and Nginx Proxy Manager path.
- The selected platform does not require direct host port exposure.
- The selected platform handles reverse proxy headers and HTTPS detection predictably.

## Functionality

- Each evaluated platform supports the collaboration features actually required by HomeLab07.
- Each evaluated platform supports browser-based file upload and download.
- Each evaluated platform supports folder creation.
- Each evaluated platform supports basic sharing workflows.
- The selected platform can support the future external storage direction if needed.
- The selected platform can provide file sharing for the MVP use case.
- The selected platform can support Windows synchronization for the MVP use case.
- The selected platform can support mobile access for the MVP use case.
- The selected platform can fit into a managed backup model.
- The selected platform can support reproducible branding without introducing disproportionate operational complexity.

## Maintainability

- One or more alternatives may be easier to document, reproduce, and recover than OwnCloud Community for the HomeLab07 use case.
- The selected platform introduces less operational complexity than it removes.

---

# Research Questions

## Platform Fit

- What services does each alternative require for a minimal HomeLab07 deployment?
- Which alternatives require MariaDB, Valkey, PostgreSQL, object storage, or another stateful dependency?
- Can each alternative run cleanly on the existing Docker network model?
- Does any alternative require changes to `homelab07-internal` or `homelab07-proxy`?

## Image And Versioning

- What Docker image should be evaluated for each alternative?
- What image tag is appropriate for a reproducible test for each alternative?
- Is a pinned version available and suitable for each alternative?
- Are `latest` or release candidate images avoidable for each alternative?

## Persistence

- What directories must be persisted?
- Which paths contain configuration?
- Which paths contain user data?
- Which paths are safe to back up and restore independently?
- What ownership and permission model is required on NAS-backed storage?
- Can each alternative coexist with the current NAS data model without becoming the owner of existing NAS data?
- Which integration mechanisms are viable for existing NAS data: controlled import, synchronization, or read-only exposure?
- What risks exist if existing NAS data is used directly as primary collaboration platform storage?

## Recovery

- Can files be recovered directly from the NAS without application-managed encryption?
- What state is required for a complete restore?
- What happens if only files are restored?
- What happens if only configuration is restored?

## Reverse Proxy

- What public URL settings are required by each alternative?
- What trusted proxy settings are required by each alternative?
- Are WebSocket or long-lived connection settings required?
- Does each alternative behave correctly behind Nginx Proxy Manager?

## Security

- Can each alternative run without publishing host ports?
- What authentication model is available in a minimal deployment?
- What security features are required for a personal homelab?
- Which security features should be deferred to a later identity sprint?
- Can each alternative integrate with a future Authentik-based OIDC identity model without requiring architecture changes?

## Platform Ecosystem

- Can each alternative coexist with Jellyfin as an independent HomeLab07 service?
- Can each alternative and Jellyfin share NAS-backed source data safely without either application becoming the owner of the other's data?
- Should media libraries remain read-only to Jellyfin and outside collaboration-platform-managed storage?
- Can the selected collaboration platform, Jellyfin, and future services share an Authentik identity layer while keeping service data independent?
- Can the selected collaboration platform provide a controlled workflow for adding or updating multimedia resources that Jellyfin later indexes?
- What synchronization or import mechanism is safest between a collaboration-platform-managed upload area and NAS-backed Jellyfin media libraries?
- Can Jellyfin refresh or rescan libraries after collaboration-platform-mediated media updates without requiring manual NAS edits?

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

- What memory and CPU usage does each alternative show at idle?
- What resource usage is observed during upload and download?
- Is the resource profile simpler or lighter than OwnCloud Community for the same test workload?

## Customization

- Can branding be applied reproducibly?
- Does customization require modifying container internals?
- Does customization survive container recreation?
- Does customization introduce integrity or upgrade risks?

---

# MVP Capability Targets

The alternatives evaluation should validate whether each platform can support the following MVP capabilities for HomeLab07:

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

The spike should evaluate a possible collaboration platform and Jellyfin coexistence model for multimedia resources.

Jellyfin should be treated as the media playback and indexing service.

The evaluated collaboration platform should be treated as a collaboration and controlled upload/update surface.

The evaluation must avoid a model where both applications write freely to the same application-managed storage tree.

## Candidate Model

```text
Collaboration platform controlled upload area
    -> reviewed import or synchronization process
    -> NAS media library
    -> Jellyfin read-only media library mount
```

In this model:

- The collaboration platform does not own the Jellyfin media library.
- Jellyfin does not write into collaboration-platform-managed storage.
- The NAS remains the authoritative media storage layer.
- Media updates occur through a controlled import or synchronization workflow.
- Jellyfin indexes media after the controlled update is complete.

## Evaluation Questions

- Can the selected collaboration platform expose a dedicated upload area for new media resources?
- Can a controlled job move or synchronize approved media into the NAS media library?
- Should synchronization be one-way only from the collaboration platform upload area to NAS media library?
- Should Jellyfin media mounts be read-only by default?
- How are deletions handled without accidental data loss?
- How are partial uploads prevented from being indexed by Jellyfin?
- Can Jellyfin library scans be triggered or scheduled after updates?
- What metadata side effects does Jellyfin create, and where are they stored?
- Can backups clearly separate collaboration platform state, NAS media, and Jellyfin config/cache?

## Non-Goals

- The collaboration platform must not become the primary media library database.
- Jellyfin must not become a file collaboration tool.
- The spike must not implement automatic media workflows before storage ownership is validated.
- The spike must not expose existing NAS media libraries as writable collaboration platform primary storage without validation.

---

# Scope

## In Scope

- Review documentation for OwnCloud Community, oCIS, OpenCloud, and Seafile.
- Identify the recommended Docker image and versioning strategy for each alternative.
- Define a minimal Compose deployment candidate for each alternative that remains plausible for HomeLab07.
- Define required private environment variables.
- Define persistent storage requirements.
- Define reverse proxy requirements.
- Define validation commands.
- Define functional UI validation.
- Compare operational complexity against the Sprint 005 OwnCloud Community implementation.
- Document findings in repository documentation.

---

# Exclusions

The following are out of scope for this spike:

- Production migration from OwnCloud Community to another platform.
- Decommissioning OwnCloud Community.
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

Review current documentation for each evaluated alternative and identify:

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

Map each alternative's requirements to existing HomeLab07 capabilities:

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

Draft a minimal service design for each viable alternative using placeholders only.

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

If implementation is approved after the planning document is reviewed, deploy one candidate platform at a time in parallel with OwnCloud Community using:

- separate service name;
- separate storage root;
- separate private environment file;
- separate public endpoint placeholder;
- no shared production data.

The runtime evaluation must not modify the existing OwnCloud Community service.

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

- documentation review notes for each evaluated alternative.
- architecture mapping for each evaluated alternative.
- proposed minimal service design for each viable alternative.
- proposed validation checklist for each viable alternative.
- Storage and recovery assessment.
- Reverse proxy assessment.
- Resource usage observation.
- Functional UI validation notes.
- Operational comparison across OwnCloud Community, oCIS, OpenCloud, and Seafile.
- Final technical recommendation.

The final recommendation must be evidence-based.

It must not be based only on preference or implementation frustration.

---

# Risks

## Technical Risks

- One or more alternatives may require dependencies not currently present in HomeLab07.
- One or more alternatives may have a storage model that does not preserve simple NAS recovery.
- One or more alternatives may require a more complex reverse proxy setup than expected.
- One or more alternatives may require identity components that are not yet part of HomeLab07.
- One or more alternatives may not support all required collaboration workflows in the minimal deployment.

## Operational Risks

- Evaluating alternatives may distract from stabilizing the existing OwnCloud Community service.
- Running two collaboration services in parallel may create confusion if endpoints or storage roots are not clearly separated.
- A successful first-run test may hide backup, restore, upgrade, or maintenance complexity.

## Decision Risks

- The evaluation may be biased by recent OwnCloud Community implementation friction.
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

The timeline may be extended if any alternative requires identity, storage, or reverse proxy components not currently available in HomeLab07.

---

# Success Criteria

The spike succeeds if HomeLab07 can make an evidence-based decision about the collaboration platform direction.

A successful spike may result in any of the following outcomes:

- continue with OwnCloud Community;
- replace OwnCloud Community with oCIS, OpenCloud, or Seafile in a future sprint;
- keep multiple options documented;
- defer the decision until identity, backup, or storage requirements are clearer.

The spike must not be considered successful merely because one alternative appears easier or newer.

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

- Can an evaluated alternative replace OwnCloud Community without requiring architectural changes to HomeLab07?
- Which existing platform services can be reused without modification?
- Which assumptions inside HomeLab07 currently couple the platform to OwnCloud?
- Which assumptions should become generic platform capabilities instead of application-specific implementations?
- Can future collaboration platforms be integrated using the same platform services?

The spike should evaluate not only the applications themselves, but also the architectural flexibility of HomeLab07.

---

## Decision Matrix

The final recommendation should evaluate all four alternatives using the following criteria.

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
