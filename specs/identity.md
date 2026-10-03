# Identity Capability

**Status:** Implemented for supported OIDC consumers; SSO redirect and
identity-source-of-truth behavior remain under investigation

## Required behavior

- Provide reusable OpenID Connect identity through Keycloak backed by a
  dedicated least-privilege database and role in shared MariaDB.
- Support Nextcloud and Paperless-ngx OIDC while retaining local emergency
  administration and Jellyfin local authentication.
- Preserve identity state in MariaDB backups and record the deployed image
  identity in recovery metadata.
- Keep consumer-specific permissions and content owned by each application.

## Boundaries

Keycloak has no direct host port, Docker socket or privileged mode. Secrets,
real hostnames, realm exports and private recovery artifacts remain outside
Git. Mandatory SSO, universal MFA, automatic login redirects and general
bidirectional directory synchronization are not accepted behavior.

## Operational references

- [Keycloak service procedure](../services/keycloak/README.md)
- [Sprint 011 implementation contract](../sprints/SPRINT-011.md)
- [SPIKE-002 open identity questions](../sprints/SPIKE-002.md)
