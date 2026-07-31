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

