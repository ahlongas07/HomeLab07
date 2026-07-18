# SPIKE-001 — OpenCloud Research Notes

**Status:** In Progress

**Phase:** Phase 1 — Documentation Review

**Reviewed On:** 2026-07-17

---

# Purpose

Capture documentation review notes for SPIKE-001.

This document records current OpenCloud documentation findings and maps them to HomeLab07 evaluation questions.

This document does not approve implementation.

This document does not conclude that OpenCloud is better than OwnCloud Community.

This document is an evidence collection artifact for the future spike decision record.

---

# Sources Reviewed

Official sources:

- OpenCloud Requirements: `https://docs.opencloud.eu/docs/admin/getting-started/requirements/`
- OpenCloud Container Deployments: `https://docs.opencloud.eu/docs/admin/getting-started/container/`
- OpenCloud Docker Compose Overview: `https://docs.opencloud.eu/docs/admin/getting-started/container/docker-compose/`
- OpenCloud Behind External Proxy: `https://docs.opencloud.eu/docs/admin/getting-started/container/docker-compose/external-proxy/`
- OpenCloud Production Considerations: `https://docs.opencloud.eu/docs/next/admin/getting-started/container/docker-compose/docker-compose-production-considerations/`
- OpenCloud Volume Permissions: `https://docs.opencloud.eu/docs/admin/getting-started/container/docker-compose/docker-compose-volume-permissions/`
- OpenCloud Configuration System: `https://docs.opencloud.eu/docs/next/dev/server/configuration/config-system/`
- OpenCloud Docker Hub image tags: `https://hub.docker.com/r/opencloudeu/opencloud/tags`
- OpenCloud Compose repository: `https://github.com/opencloud-eu/opencloud-compose`
- OpenCloud server image overview: `https://hub.docker.com/r/opencloudeu/opencloud`

Non-official sources were not used as decision evidence in this phase.

---

# Documentation Observations

## Deployment Model

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

## Docker Image And Versioning

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

## Database

OpenCloud documentation states that OpenCloud does not use a database.

It stores files on storage instead.

Implication for HomeLab07 evaluation:

- Shared MariaDB is probably not required.
- OpenCloud may reduce platform dependency count compared to OwnCloud Community.
- This must be validated during controlled deployment.

This observation does not by itself prove that OpenCloud is operationally simpler.

## Storage Requirements

The requirements documentation identifies storage driver constraints.

The `posix` and `decomposed` storage drivers require a fully POSIX-compliant filesystem.

The documentation also calls out atomic read-after-write consistency for directory metadata.

The `posix` driver requires extended attributes.

Implication for HomeLab07:

- NAS-backed storage must be evaluated carefully.
- The Rockstor-backed filesystem and mount options must be checked against OpenCloud storage requirements.
- Direct recoverability must be validated empirically, not assumed.
- OpenCloud storage may be simpler than OwnCloud only if the NAS mount satisfies the documented filesystem requirements.

## Persistent Directories

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

## Volume Permissions

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

## Configuration System

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

## Initial Admin Password

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

## Reverse Proxy

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

## TLS And Domains

OpenCloud documentation examples assume public DNS and TLS.

Integrated Traefik handles certificates in the default path.

The external proxy path assumes TLS is handled outside OpenCloud.

Implication for HomeLab07:

- Cloudflare and Nginx Proxy Manager remain the correct publication path.
- OpenCloud should not manage TLS directly in HomeLab07.
- Real public endpoint values belong in `HomeLab07.private/`.
- Repository docs must use placeholders.

## Optional Collabora

External proxy documentation includes Collabora in the example.

It also notes that WOPI endpoints are served through OpenCloud paths and do not require a separate WOPI domain in the documented setup.

Implication for HomeLab07:

- Collabora should remain out of scope for minimal OpenCloud evaluation.
- Document editing should not be used as a first-pass comparison criterion.
- If evaluated later, it should be a separate phase because it adds reverse proxy and service complexity.

## Authentication

OpenCloud documentation references OpenID Connect and the possibility of external identity providers.

The Docker image overview states that OpenCloud authenticates users via OpenID Connect using either an external IdP or an embedded LibreGraph Connect identity provider.

Implication for HomeLab07:

- Authentication must be explicitly evaluated.
- Identity integration should remain out of scope for the minimal spike unless required for OpenCloud to function.
- Sprint 006 identity work may influence the final OpenCloud decision.

## Hardware Requirements

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

# HomeLab07 Mapping

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

# Initial Risk Register

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

# Evidence Required Next

The following evidence is required before any decision:

- selected OpenCloud image and exact tag;
- minimal Compose file set;
- list of required environment variables;
- persistent config and data paths;
- storage ownership and permission validation;
- reverse proxy configuration for Nginx Proxy Manager;
- first-run admin login validation;
- file upload and download validation;
- file recoverability validation from NAS storage;
- container recreation validation;
- resource usage observation;
- comparison against the Sprint 005 OwnCloud implementation.

---

# Preliminary Non-Conclusive Assessment

Documentation review suggests that OpenCloud may align well with HomeLab07's goals because it appears to reduce database dependency and provides a container-native deployment model.

However, this is not a conclusion.

The major unresolved question is whether OpenCloud's storage requirements work cleanly with the HomeLab07 NAS-backed storage model.

The next phase should focus on architecture mapping and minimal deployment design before any runtime implementation.
