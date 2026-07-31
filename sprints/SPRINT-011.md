# SPRINT-011 — Identity Platform

**Status:** Implementation in progress — repository capability complete; target PoC pending

**Classification:** Platform Capability

**Phase:** Phase 2 — Shared Platform Capabilities

**Selected Technology:** Keycloak 26.7.0

**First Consumer:** Nextcloud

**Last Reviewed:** 2026-07-31

---

## Objective

Introduce a reusable identity provider using OpenID Connect. Keycloak consumes
the existing shared MariaDB platform and is published only through Nginx Proxy
Manager. Nextcloud is the first controlled consumer; Paperless-ngx and
Jellyfin are explicitly deferred.

## Decision record

The earlier planning candidate, Authentik, was rejected during implementation
because it requires PostgreSQL. Adding a second relational platform was not
accepted. Keycloak was selected because its supported database matrix includes
MariaDB 11.4 LTS, the existing HomeLab07 baseline.

Official references:

- [Keycloak database support](https://www.keycloak.org/server/db)
- [Keycloak container](https://www.keycloak.org/server/containers)
- [Keycloak reverse proxy](https://www.keycloak.org/server/reverseproxy)
- [Nextcloud OIDC authentication](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_oidc.html)

## Architecture

```text
Internet
  -> Cloudflare
  -> Nginx Proxy Manager
  -> Keycloak :8080
       -> shared MariaDB / dedicated keycloak database
  -> Nextcloud
       -> OIDC authorization-code flow -> Keycloak
```

Keycloak joins `homelab07-internal` and `homelab07-proxy`, publishes no host
ports and mounts no Docker socket. MariaDB remains internal-only. Identity
state is held in a dedicated MariaDB database and role.

## Scope

### Included

- Pinned Keycloak container definition.
- Dedicated MariaDB database and least-privilege user provisioning.
- Nginx Proxy Manager publication contract.
- OIDC realm and Nextcloud client runbook.
- Operation-layer start, stop and status integration.
- MariaDB logical backup and recovery-manifest coverage.
- Local administrative break-glass and rollback validation.

### Excluded

- Mandatory SSO or automatic login redirect.
- MFA enforcement.
- Removal of local application administrators.
- Paperless-ngx and Jellyfin activation.
- LDAP, SAML, social identity providers and directory federation.
- High availability or multi-node Keycloak.

## Repository deliverables

```text
services/keycloak/
├── .env.example
├── IMPLEMENTATION_NOTES.md
├── README.md
└── compose.yaml

operation/
├── keycloak-db-create.sh
└── keycloak-db-drop.sh
```

The lifecycle scripts, backup manifest, platform documentation and Nextcloud
documentation are updated as part of the implementation.

## Security contract

- Secrets, real hostnames and identities remain in `HomeLab07.private/`.
- Keycloak is reachable externally only through the shared proxy and edge.
- Strict hostname processing and forwarded headers are configured.
- Direct access grants are disabled for the Nextcloud client.
- Redirect URIs and web origins are exact, not wildcarded.
- A named Keycloak emergency administrator replaces bootstrap credentials.
- Nextcloud local administrator login remains enabled and tested.
- Client secrets are unique per consumer.

## Backup and recovery

The existing `mariadb-dump --all-databases` recovery artifact includes the
Keycloak database. `operation/backup.sh` records the Keycloak container image
alongside the other platform services. Private configuration is covered by the
encrypted recovery point.

Recovery order:

1. Restore MariaDB and import the matching logical dump.
2. Restore private Keycloak configuration.
3. Deploy the pinned Keycloak image.
4. Validate realm discovery and emergency administration.
5. Restore proxy publication.
6. Validate Nextcloud local login before testing OIDC.

A realm export is required before planned Keycloak upgrades and must remain in
the private recovery boundary.

## Implementation sequence

1. Create `HomeLab07.private/env/keycloak.env` from the example.
2. Create the dedicated database with `operation/keycloak-db-create.sh`.
3. Deploy Keycloak and validate health without host-port mappings.
4. Publish its private hostname through Nginx Proxy Manager.
5. Create the `homelab07` realm, emergency administrator and PoC group.
6. Create a confidential Nextcloud OIDC client.
7. Install and configure Nextcloud `user_oidc` during a recovery-backed window.
8. Validate login, logout, denial, local break-glass and rollback.
9. Run backup, integrity check and disposable restore.

## Acceptance criteria

- Keycloak runs from `quay.io/keycloak/keycloak:26.7.0` and its runtime digest
  is recorded during target validation.
- Keycloak uses the existing MariaDB 11.4 platform through a dedicated role.
- No new database platform, public host port, privileged mode or Docker socket
  is introduced.
- The external discovery endpoint is served through Cloudflare and NPM.
- One authorized Nextcloud PoC user completes OIDC login and logout.
- Unauthorized access is denied.
- Local Keycloak and Nextcloud emergency administration remains functional.
- Disabling `user_oidc` restores local-only Nextcloud authentication.
- A post-implementation backup and disposable restore validate the Keycloak
  database recovery boundary.
- Documentation contains no production hostname, address or credential.

## Evidence required for closure

- Sanitized Compose status and image identity.
- No host-port mapping result.
- Sanitized OIDC discovery and successful login/logout evidence.
- Local-login and rollback results.
- Backup, integrity and disposable-restore results.
- Updated Landing Page and changelog.

Sprint 011 remains open until target runtime evidence satisfies every
acceptance criterion.
