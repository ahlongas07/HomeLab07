# Identity Authority PoC Runbook

## Purpose

Execute SPIKE-002 without treating unverified identity behavior as production
policy. The PoC covers Keycloak profile claims, Nextcloud reconciliation,
Paperless-ngx just-in-time provisioning, the HomeLab07 login theme and default
SSO redirection.

## Recovery gate

Before changing the realm or consumer configuration:

1. Run `./operation/backup.sh`.
2. Run a disposable restore of that recovery point.
3. Test the local Nextcloud and Paperless administrators.
4. Record the private emergency URLs outside Git.
5. Export the `homelab07` realm into the encrypted private recovery boundary.

Do not continue if any recovery check fails.

## Keycloak profile contract

In **Realm settings → User profile**, keep unmanaged attributes disabled and
create a managed `picture` attribute:

- user and administrator may view it;
- only the approved operator may edit it during the PoC;
- maximum length is 2048 characters;
- a regular-expression validator restricts it to an approved HTTPS avatar
  origin.

Create or verify client-specific protocol mappings:

| Source | Claim | Token locations |
|---|---|---|
| Keycloak immutable user ID | `sub` | standard OIDC claim |
| Username | `preferred_username` | ID token, access token, userinfo |
| First name | `given_name` | ID token, access token, userinfo |
| Last name | `family_name` | ID token, access token, userinfo |
| Display name | `name` | ID token, access token, userinfo |
| Verified email | `email` | ID token, access token, userinfo |
| User attribute `picture` | `picture` | ID token, access token, userinfo |

Do not enable a broad realm-role mapper. Groups and application roles remain a
separate gate after basic attribute lifecycle tests pass.

## Nextcloud provider

First record the installed application and provider configuration without
printing the client secret:

```bash
docker exec --user www-data homelab07-nextcloud php occ \
  app:list --enabled
docker exec --user www-data homelab07-nextcloud php occ \
  user_oidc:provider
docker exec --user www-data homelab07-nextcloud php occ \
  user_oidc:provider <provider-id>
docker exec --user www-data homelab07-nextcloud php occ \
  user_oidc:provider --help
```

Configure these mappings through the supported OpenID Connect administration
UI or the exact options reported by the installed `occ` help:

| Nextcloud field | Claim |
|---|---|
| User ID | `sub` |
| Display name | `name` |
| Email | `email` |
| Avatar | `picture` |
| Groups | leave disabled during the first PoC phase |

Changing the User ID mapping of an established provider can make existing
accounts inaccessible. Use a new non-administrator PoC identity and inventory
current links before applying `sub` to existing users.

The version-controlled operation applies the provisioning and redirect flags:

```bash
./operation/identity-poc.sh apply --confirm-local-admin-tested
```

The local emergency route is the private Nextcloud login URL with `?direct=1`.
Test it immediately after applying the change.

## Paperless-ngx policy

The private environment must contain:

```dotenv
PAPERLESS_SOCIAL_AUTO_SIGNUP=true
PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS=true
PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS=false
PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS_CLAIM=groups
PAPERLESS_DISABLE_REGULAR_LOGIN=false
PAPERLESS_REDIRECT_LOGIN_TO_SSO=true
```

The operation script validates these switches without printing the OIDC JSON
or client secret and recreates Paperless-ngx. Group synchronization remains
disabled until removal semantics and group permissions have passed a later
gate.

## Login theme

The repository mounts `services/keycloak/themes/homelab07` read-only into the
container and reuses the existing HomeLab07 visual assets through a separate
read-only mount.

After recreating Keycloak:

```bash
./operation/compose.sh keycloak up -d
./operation/identity-poc.sh status
```

Select **homelab07** under **Realm settings → Themes → Login theme**. Exercise
password login, invalid credentials, OTP setup and challenge, recovery codes,
expired actions, logout and a mobile viewport. Restore the built-in theme from
the same realm setting if any page is incomplete.

## Attribute test matrix

Change only one value per test and start a fresh login:

| Test | Nextcloud | Paperless-ngx |
|---|---|---|
| First login | account created | account created |
| Given/family name | record result | record result |
| Display name | record result | record result |
| Email | record result | record result |
| Avatar URI | must update | unsupported unless runtime proves otherwise |
| Conflicting local edit | record overwrite behavior | record ownership behavior |
| Disable + revoke sessions | access denied | access denied |
| Username change | must not duplicate | must not duplicate |

Do not test username changes against an identity that owns real content.

## Status and rollback

Inspect only non-secret switches:

```bash
./operation/identity-poc.sh status
```

To restore the Nextcloud login chooser, run:

```bash
./operation/identity-poc.sh rollback
```

The command will refuse to recreate Paperless-ngx until the operator first
sets `PAPERLESS_REDIRECT_LOGIN_TO_SSO=false` in private configuration. The
Keycloak theme is reverted independently by selecting the previous Login theme
in the realm.

Rollback does not delete OIDC-provisioned users or application content.

## Evidence

Record only sanitized outcomes in `sprints/SPIKE-002.md`:

- image identities and application versions;
- claim names, never claim values from real users;
- pass/fail for each attribute and lifecycle action;
- theme coverage and accessibility observations;
- emergency access and redirect rollback;
- backup and disposable restore results.

Never record tokens, secrets, real names, email addresses, avatar URLs or
production endpoints.
