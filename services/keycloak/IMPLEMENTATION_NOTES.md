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

## Security Update 26.7.0 → 26.7.5

Approved on 2026-10-22 as a patch update within the 26.7 minor line; no
configuration change.

| | Previous | Target |
|---|---|---|
| Tag | `quay.io/keycloak/keycloak:26.7.0` | `quay.io/keycloak/keycloak:26.7.5` |
| Index digest | `sha256:0f198be292568439d700cdbfb893e69a6009bb43a94a06a945b1d3d506c76b13` | `sha256:37dbaf6f0722c9ec246335f36e1ef8b2e6cb960f7c27e0d8c615121a3d475a85` |
| amd64 manifest | — | `sha256:6529db34610ce6328824218dce3bbe55c4ba4757bc5c8a09b5a4c746e28b6e9d` |
| arm64 manifest | — | `sha256:e301e41716af5db8261488ae16c4ef77bb5e9bcdcf981685570929e0cb8f3905` |
| Upstream release | 2026-07-09 | 2026-09-30, latest 26.7 patch |

Digests were read from Quay on 2026-10-22.

Upstream advisories affecting 26.7.0 and fixed within 26.7:
GHSA-4gv3-mc9p-5wqc (critical, account takeover through the reset-credentials
flow; fixed in 26.7.2), GHSA-xpwp-2pcm-8xq3 (high, replay protection bypass;
26.7.4), and GHSA-2888-g6qc-w4mj, GHSA-95rm-h7g9-rhcf, GHSA-fgq2-hxm5-8xg2,
GHSA-f8m4-v488-rmrm, GHSA-95cx-vmr5-3cmr, GHSA-hmr6-pxx9-552p and
GHSA-3692-rrj9-24qw (26.7.1). 26.7.5 adds further fixes listed in its release
notes. Applicability on 2026-10-22: password reset and self-registration are
disabled in every realm and no external identity provider is configured, which
reduces the critical and SAML broker issues; the remaining issues were
treated as applicable. 26.8 adds no further security fix and was not chosen.

Recovery artifacts: the platform recovery point taken earlier the same day
(MariaDB dump including the Keycloak database) and a full realm export taken
immediately before the upgrade with a disposable 26.7.0 container
(`export --users realm_file --cache=local`) into the private evidence
location. The export contains users and client secrets and never enters Git.

Target result (2026-10-22, update at 20:42 UTC, about 40 seconds without
login). Detailed evidence remains in the private evidence location.

- [x] Runtime `quay.io/keycloak/keycloak:26.7.5@sha256:37dbaf6f…`, healthy,
      no restarts; Liquibase database update without errors. Startup
      warnings are the default deprecated-feature notice and an empty-query
      notice from the MariaDB driver.
- [x] Discovery answers for every realm, locally and through Cloudflare; the
      admin console answers.
- [x] The login page reached from Nextcloud serves the custom `homelab07`
      theme and the login form.
- [x] Nextcloud and Paperless-ngx redirect to Keycloak; the project owner
      completed a login with OTP. The application on the second realm also
      authenticates through Keycloak.
- [x] NPM access audit passes.
- [x] Security scan compared with the last 26.7.0 run on the private share:
      no new finding; the only remaining critical finding is in the base
      image CA bundle without a published fix. Accepted.
