# SPIKE-002 — Identity Source of Truth and SSO Experience

**Status:** Approved — controlled PoC implementation prepared; runtime evidence pending

**Classification:** Platform Capability Investigation

**Phase:** Phase 2 — Shared Platform Capabilities

**Created:** 2026-08-06

**Depends On:** Sprint 011 — Identity Platform

---

## Objective

Determine whether Keycloak can become HomeLab07's authoritative source for
supported user identity attributes across Nextcloud and Paperless-ngx while
also providing a version-controlled login theme and default SSO redirection.

The Spike addresses three questions:

1. Which accounts and attributes can Keycloak create and update reliably in
   each consumer?
2. How should the Keycloak login experience be branded without creating an
   upgrade-sensitive fork?
3. Can application entry points redirect to Keycloak by default while
   preserving tested local emergency access?

This document does not approve production implementation. A controlled PoC
must resolve the identified compatibility and lifecycle gates first.

## Desired user experience

```text
User opens supported application
             |
             v
Application redirects to Keycloak
             |
             v
HomeLab07 login theme + password + OTP
             |
             v
OIDC claims create or update the local application identity
```

Keycloak owns authentication credentials and the canonical identity profile.
Each application continues to own its content, application-specific settings,
permissions that cannot be represented safely as claims, and recovery account.

## Meaning of source of truth

For this Spike, source of truth means:

- users are created in the `homelab07` realm;
- supported consumers create a local projection on first OIDC login;
- approved Keycloak claims overwrite their mapped local attributes at the next
  successful login;
- groups may be projected only through an application-specific whitelist;
- credentials, OTP and account enablement remain controlled by Keycloak;
- local application administrators remain outside normal federation.

It does not mean:

- real-time push synchronization;
- bidirectional updates from applications back into Keycloak;
- deletion of application content when a Keycloak user is removed;
- automatic mapping of every application field;
- automatic pre-provisioning before the first login;
- shared application administrator privileges.

OIDC is an authentication and claims protocol, not a general-purpose
bidirectional directory synchronization protocol. Most reconciliation occurs
when a new login supplies fresh claims.

## Canonical identity model

The PoC must define a small, stable schema before configuring mappings:

| Canonical value | Keycloak source | OIDC claim | Mutability |
|---|---|---|---|
| Internal identity | Keycloak user ID | `sub` | Immutable |
| Login name | `username` | `preferred_username` | Change only after migration testing |
| Given name | `firstName` | `given_name` | Mutable |
| Family name | `lastName` | `family_name` | Mutable |
| Display name | derived or managed attribute | `name` | Mutable |
| Email | `email` | `email` | Mutable and verified |
| Avatar reference | managed `picture` attribute | `picture` | Mutable trusted HTTPS URI |
| Application groups | client-specific roles or groups | `groups` | Mutable, whitelisted |

The application user identifier must never be based on email. Email and
username changes can otherwise create duplicate or inaccessible projections.
The PoC must verify whether the current Nextcloud provider can map `sub`
without disrupting existing accounts.

## Keycloak user profile

Keycloak User Profile supports a managed schema, validation and separate view
and edit permissions for users and administrators. The proposed schema should
keep unmanaged attributes disabled and explicitly define only approved fields.

The `picture` attribute should contain a trusted HTTPS URI and be exposed as
the standard OIDC `picture` claim. Keycloak does not need to store image binary
data. Allowing arbitrary remote avatar URIs creates a content and tracking
risk, so the attribute requires a URL validator restricted to an approved
HomeLab07-controlled origin.

Protocol mappers and client scopes must emit only the claims required by each
consumer. Do not expose all realm roles or profile attributes to every client.

Official references:

- [Keycloak user profiles](https://www.keycloak.org/docs/latest/server_admin/#user-profile)
- [Keycloak avatar support](https://www.keycloak.org/ui-customization/avatars)
- [Keycloak protocol mappers](https://www.keycloak.org/admin-api/protocol-mappers)

## Nextcloud assessment

The supported `user_oidc` application can create users at first login and
update mapped attributes from OIDC claims. Its documented surface includes:

- user ID;
- display name;
- email;
- quota;
- groups;
- avatar from an HTTPS URL or a supported base64 image;
- optional enrichment from the OIDC userinfo endpoint.

The recommended PoC model is:

```text
auto_provision=true
soft_auto_provision=true
disable_account_creation=false
```

This permits creation of new OIDC users and controlled reconciliation of
existing users. Before adopting it, the PoC must identify every existing local
account and prevent accidental merging with the emergency administrator.

Group provisioning must use a dedicated prefix and whitelist, for example
`/nextcloud/*`. It must not map a broad realm role directly to Nextcloud's
reserved `admin` group during the Spike.

Avatar validation must prove:

1. a trusted `picture` URI reaches Nextcloud through the mapped avatar claim;
2. the image is square and in a supported format;
3. changing the URI in Keycloak updates the avatar after a new login;
4. a local avatar change is either overwritten predictably or prohibited by
   documented policy;
5. an unavailable avatar origin does not block authentication.

Nextcloud pre-provisioning before first login is possible through the
`user_oidc` API, but Keycloak does not invoke it automatically. Automating that
API would introduce a provisioning component and credentials and is outside
the initial PoC.

Official references:

- [Nextcloud OIDC administration](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_oidc.html)
- [Nextcloud `user_oidc`](https://github.com/nextcloud/user_oidc)

## Paperless-ngx assessment

Paperless-ngx supports OIDC through django-allauth and already uses approved
just-in-time account creation. Its documented synchronization capability is
narrower than Nextcloud's:

- social account creation from OIDC identity data;
- default groups on social signup;
- group membership synchronization at login;
- a configurable groups claim.

The current documentation does not establish support for an OIDC-managed
avatar or guaranteed continuous synchronization of every profile field.
Paperless-ngx also owns document permissions, workflow configuration and other
application-specific state that must never be inferred from arbitrary profile
claims.

The PoC must determine empirically whether changes to `preferred_username`,
`name` and `email` update an existing Paperless user after login. Unsupported
fields remain locally owned and must be documented rather than supplemented by
custom database writes or an unmaintained plugin.

Group synchronization may be evaluated only with pre-created Paperless groups
and a dedicated claim. No Keycloak role may grant Paperless superuser or staff
status during this Spike.

Official references:

- [Paperless-ngx authentication configuration](https://docs.paperless-ngx.com/configuration/#authentication-sso)
- [Paperless-ngx OIDC integration](https://docs.paperless-ngx.com/advanced_usage/#openid-connect-and-social-authentication)

## Lifecycle semantics

The PoC must record behavior for each event:

| Keycloak action | Required consumer result |
|---|---|
| Create user | Account is created on first approved login |
| Change name/email | Supported mapped fields reconcile on next login |
| Change avatar URI | Nextcloud updates; Paperless behavior is documented |
| Add/remove group | Whitelisted local groups reconcile on next login |
| Disable user | New authentication is denied and active sessions are revoked during the test |
| Delete user | Login is denied; application data and local projection are retained pending reviewed offboarding |
| Rename username | No duplicate account or loss of content; otherwise the operation is prohibited |

Disabling or deleting a Keycloak account does not by itself delete Nextcloud
files or Paperless documents. Offboarding must separate access revocation from
content retention, transfer and deletion.

## Login theme assessment

The production candidate is a small version-controlled Keycloak login theme
that extends the bundled theme and overrides assets, CSS and message bundles
before it overrides Freemarker templates.

Proposed repository boundary:

```text
services/keycloak/themes/homelab07/login/
├── theme.properties
├── messages/
└── resources/
    ├── css/
    └── img/
```

The theme should be mounted read-only into the Keycloak container. It must use
existing HomeLab07 assets where suitable, contain no environment-specific
domain and remain reproducible from Git.

Keycloak's Quick Theme is not the baseline because it is a preview feature.
Direct modification of bundled themes is prohibited. Template overrides are a
last resort because Keycloak upgrades can change their contract.

The PoC must cover login, invalid credentials, OTP enrollment and challenge,
recovery codes, logout, expired actions, mobile layout and accessibility.

Official references:

- [Working with Keycloak themes](https://www.keycloak.org/ui-customization/themes)
- [Keycloak Quick Theme status](https://www.keycloak.org/ui-customization/quick-theme)

## Default SSO redirection

### Nextcloud

With one provider, `user_oidc` can redirect directly to Keycloak by setting
`allow_multiple_user_backends` to `0`. The documented emergency route adds
`?direct=1` to the Nextcloud login URL. The PoC must bookmark and test that
route before enabling redirect behavior.

### Paperless-ngx

`PAPERLESS_REDIRECT_LOGIN_TO_SSO=true` redirects the normal login experience to
the first configured SSO provider. `PAPERLESS_DISABLE_REGULAR_LOGIN` should
remain `false` during the PoC. The exact local emergency route, including the
Django administration path, must be tested before any later decision to hide
the regular frontend login.

### Safety rules

- Never remove the local Keycloak emergency administrator.
- Preserve one local administrator in Nextcloud and Paperless-ngx.
- Store and test emergency URLs outside the public repository.
- Test behavior when Keycloak, DNS or the reverse proxy is unavailable.
- Do not redirect health checks, WebDAV, APIs, application passwords or OIDC
  callback paths.
- Confirm that logout terminates the expected Keycloak session and does not
  create a redirect loop.

## PoC phases

### Phase 1 — Identity contract

1. Export and back up the realm and application state.
2. Inventory existing users, identifiers, emails, groups and account links.
3. Define the managed Keycloak User Profile schema.
4. Define client-specific scopes and claim mappings.
5. Create a non-administrator PoC identity with a trusted avatar URI.

### Phase 2 — Attribute reconciliation

1. Validate first-login creation in Nextcloud and Paperless-ngx.
2. Change one attribute at a time in Keycloak.
3. Start a new authentication and record each local result.
4. Attempt a conflicting local edit and record ownership behavior.
5. Validate group removal as well as group addition.
6. Disable the user, revoke sessions and verify access denial.

### Phase 3 — Theme

1. Build a minimal CSS-and-assets theme in the repository.
2. Mount it read-only in a non-production validation window.
3. Select it only for the `homelab07` realm.
4. Exercise every login and recovery state.
5. Restore the built-in theme as rollback.

### Phase 4 — Redirect

1. Confirm local emergency access immediately before the change.
2. Enable Nextcloud default OIDC redirection.
3. Enable Paperless SSO redirection without disabling local login.
4. Test browser, mobile, WebDAV and API consumers.
5. Simulate Keycloak unavailability and exercise both break-glass paths.
6. Revert both redirect settings and prove local-only recovery.

## Acceptance criteria

The Spike may recommend implementation only when:

- the canonical identifier cannot change accidentally;
- first-login creation succeeds in both supported consumers;
- the exact supported attribute matrix is documented from runtime evidence;
- avatar update behavior is proven for Nextcloud and explicitly resolved for
  Paperless-ngx;
- local changes cannot silently become authoritative for managed fields;
- group removal is reflected as reliably as group addition;
- disabling a Keycloak user blocks access after session revocation;
- the version-controlled theme covers password, OTP, error and recovery flows;
- automatic redirects preserve tested local emergency routes;
- callback, WebDAV, API and mobile-client behavior remains functional;
- backup, rollback and disposable restore succeed after the PoC;
- no secret, production endpoint or personal identity enters Git.

## Decision outcomes

The Spike must end with one of these decisions:

1. **Approve bounded identity authority:** Keycloak owns only the proven
   attribute matrix and applications own everything else.
2. **Approve authentication only:** retain centralized login but do not claim
   profile authority where reconciliation is unreliable.
3. **Approve per-consumer scope:** enable authority for Nextcloud but not
   Paperless-ngx, or the reverse, based on evidence.
4. **Reject forced redirect:** retain visible SSO buttons if emergency access
   or client compatibility is insufficient.

The result must not describe Keycloak as the source of truth for “all data”
unless every claimed field and lifecycle operation is explicitly validated.

## Implementation entry

The team approved controlled execution on 2026-08-06. Repository preparation
adds:

- a CSS-and-messages Keycloak login theme mounted read-only;
- explicit Paperless-ngx identity and redirect switches;
- `operation/identity-poc.sh` for status, guarded application and redirect
  rollback;
- a recovery-first runtime runbook at
  `services/keycloak/IDENTITY_AUTHORITY_POC.md`.

No runtime claim is accepted until the target-host matrix and rollback tests
are recorded below.

## Runtime evidence

Pending controlled target-host execution.
