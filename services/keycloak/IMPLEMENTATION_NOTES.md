# Keycloak / Nextcloud OIDC PoC Runbook

## Preconditions

1. Create and restore-test a current recovery point.
2. Confirm the existing Nextcloud administrator can log in locally.
3. Deploy Keycloak and validate its health and discovery endpoint.
4. Create the `homelab07` realm and a named emergency administrator.

## Keycloak client

Create an OpenID Connect client for Nextcloud with:

- client authentication enabled;
- standard authorization-code flow enabled;
- direct access grants disabled;
- redirect URI `https://<collaboration-domain>/apps/user_oidc/code`;
- web origin restricted to the collaboration origin;
- scopes `openid`, `profile` and `email`.

Store the client secret only in private configuration. Use a dedicated PoC
group and users; do not attach global mandatory policies.

## Nextcloud consumer

Install and enable the supported `user_oidc` application with `occ`. Register
the provider using Keycloak's issuer:

```text
https://<identity-domain>/realms/homelab07
```

Keep password login enabled. Do not enable automatic account provisioning or
group synchronization until returned claims have been reviewed.

## Acceptance tests

1. Local Nextcloud administrator login still succeeds.
2. An authorized PoC user authenticates through Keycloak and returns safely.
3. Logout completes without a redirect loop.
4. An unauthorized user is rejected.
5. WebDAV/application-password behavior is recorded.
6. Disabling `user_oidc` restores local-only authentication.

## Rollback

Disable `user_oidc`, remove the Keycloak Proxy Host if necessary and stop
Keycloak. Preserve the database until evidence and rollback are accepted.

## Target-host acceptance

Acceptance completed on 2026-08-06 with sanitized evidence:

- `quay.io/keycloak/keycloak:26.7.0` was healthy with runtime image ID
  `sha256:60e153026e8f53ee2c3877b23aa664a6fb24ea99c57085b40cbb77ca2be01e3d`;
- the reproducible service definition now pins the reviewed OCI index digest
  `sha256:0f198be292568439d700cdbfb893e69a6009bb43a94a06a945b1d3d506c76b13`;
- `docker port homelab07-keycloak` returned no host mappings;
- realm discovery and Nextcloud OIDC login/logout succeeded;
- local emergency access remained available;
- Paperless-ngx authenticated through Keycloak with OTP and accepted
  just-in-time creation of non-administrator users;
- a consistent encrypted recovery point passed Restic integrity checks;
- a disposable restore recovered 75,891 entries (2.171 GiB), validated two
  artifacts and one database dump, and did not start services or modify
  production paths.

Jellyfin remains locally authenticated. A third-party SSO plugin was reviewed
and rejected because its support, client coverage and account-permission risks
were not justified by the platform requirement.
