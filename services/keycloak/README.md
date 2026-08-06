# Keycloak Identity Platform

## Purpose

Keycloak provides HomeLab07's reusable OpenID Connect identity capability.
Sprint 011 validates Nextcloud as the first consumer while preserving local
emergency access. Paperless-ngx is an accepted additional consumer. Jellyfin
retains local authentication because it has no supported native OIDC path.

## Responsibilities

- Central user, realm, role and session management.
- OpenID Connect provider functionality.
- Reusable identity boundary for platform applications.

Keycloak does not own TLS, DNS or database infrastructure. OTP was validated
for selected identities; realm-wide MFA and mandatory SSO remain outside
Sprint 011.

## Technology

| Capability | Selection |
|---|---|
| Identity server | `quay.io/keycloak/keycloak:26.7.0` |
| Database | Shared MariaDB 11.4, dedicated database and role |
| Protocol | OpenID Connect |
| Publication | Nginx Proxy Manager and Cloudflare |

The container joins internal and proxy networks but publishes no host ports.
No Docker socket or privileged mode is used.

## Directory structure

```text
services/keycloak/
├── .env.example
├── IDENTITY_AUTHORITY_POC.md
├── IMPLEMENTATION_NOTES.md
├── README.md
├── compose.yaml
└── themes/
    └── homelab07/
```

Identity state lives in MariaDB. The repository owns the runtime definition;
private credentials, domains and exported realm recovery artifacts remain in
`HomeLab07.private/` and its encrypted backup.

## Configuration

```bash
cp services/keycloak/.env.example ../HomeLab07.private/env/keycloak.env
chmod 600 ../HomeLab07.private/env/keycloak.env
```

Generate separate database and bootstrap passwords. After first login, create
a named emergency administrator and rotate the bootstrap account credential;
Keycloak ignores bootstrap creation when an administrator already exists.

## Deployment

```bash
./operation/compose.sh mariadb up -d
./operation/keycloak-db-create.sh
./operation/compose.sh keycloak up -d
```

The Compose definition mounts the version-controlled `homelab07` login theme
and existing platform assets read-only. Theme selection is realm state and is
performed only during the controlled SPIKE-002 procedure.

Configure Nginx Proxy Manager to forward the private identity hostname to
`homelab07-keycloak:8080` over HTTP. Keep TLS mode Full (strict) at the edge.

## Validation

```bash
./operation/compose.sh keycloak ps
docker port homelab07-keycloak
docker inspect homelab07-keycloak --format '{{.Config.Image}} {{.Image}}'
```

The port command must return no mappings. Validate the admin console, realm
discovery endpoint, Nextcloud OIDC flow, logout, denied-user behavior, local
break-glass access and rollback.

## Backup and restore

The MariaDB logical dump contains the Keycloak database. The platform backup
also records the image identity and private configuration. Before a planned
upgrade, export the realm into the approved private backup boundary as an
additional recovery artifact. Restore MariaDB before starting Keycloak.

## Security

- Dedicated least-privilege MariaDB user.
- No direct host ports, privileged mode or Docker socket.
- Secrets and public hostname remain private.
- Local service administrators remain available during the PoC.
- Realm-wide MFA and mandatory SSO are deferred to a later Sprint.

## Related Sprint

- Sprint 011 — Identity Platform
- SPIKE-002 — Identity Source of Truth and SSO Experience
