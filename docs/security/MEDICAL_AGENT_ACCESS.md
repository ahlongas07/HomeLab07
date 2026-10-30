# Medical Agent Access

## Decision

The medical agent reads exams from Paperless-ngx through the public route
(Cloudflare → Caddy → Paperless-ngx) with a Paperless API token
for the read-only user `agente-medico`. It does not use Keycloak or OTP: API
tokens bypass the browser login flow by design.

Accepted by the project owner on 2026-10-22, after the read-only validation
passed (12 of 12 checks). Rationale and limits:

- The account is read-only, so a leaked token exposes exams but cannot change
  or delete them. `model-init` reconciles its rights on every run (see
  [Paperless Medical Sync](../../services/paperless-medical-sync/README.md#read-only-users)).
- Accepted risk: exam content read by the agent reaches the cloud provider of
  the language model the agent uses.
- Accepted risk: the token grants access without a second factor; it is
  stored only in the agent's private environment and rotated as described
  below.
- No Cloudflare exception is created. The proxied route keeps the edge policy
  in [EDGE_POLICY.md](EDGE_POLICY.md), including the Cloudflare-only access
  list on the origin.

## Client requirements

- Send every request with `Authorization: Token <token>` and
  `Accept: application/json; version=10`.
- Send an explicit, application-specific `User-Agent`. Cloudflare Browser
  Integrity Check rejects default library agents such as `Python-urllib`
  with error 1010; the check stays enabled.
- Follow pagination links as returned. They use `https` once Paperless trusts
  the forwarded scheme (`PAPERLESS_PROXY_SSL_HEADER`, see the
  [Paperless-ngx README](../../services/paperless-ngx/README.md#https-scheme-behind-the-proxy)).

## Adding a read-only user

1. Create the Paperless user without staff, superuser or groups. Do not create
   a password-based login for an agent account.
2. Add the user name to `SYNC_READER_USERNAMES` in the private
   `paperless-medical-sync.env`.
3. Delete the "Exámenes médicos" workflow in Paperless: the existing workflow
   lacks the new viewer, which `model-init` reports as drift.
4. Create a temporary token for a **superuser** and run `model-init` with it
   (Paperless only lets a non-superuser bulk-edit objects it owns):

   ```bash
   ./operation/compose.sh paperless-medical-sync run --rm \
     paperless-medical-sync medical-sync model-init
   ```

5. Delete the temporary superuser token immediately.
6. Generate the reader's token (next section) and store it only in the
   client's private environment.
7. Validate: the reader sees exams, the contract tags, the exam owner's
   correspondents and the exam document type, and nothing owned by another
   user; a `PATCH` or `DELETE` with its token returns `403`; a new exam
   uploaded by the sync is visible to it. The isolation part is automated
   (token on stdin, only counts printed):

   ```bash
   ./operation/paperless-access-check.sh medical-reader
   ```

   Expected: `4/4 checks passed` (ISO-06). A `WARN` line means objects
   without owner are visible; `model-init` lists them.

## Rotating the token

Regenerate the token, which invalidates the previous one:

```bash
./operation/compose.sh paperless-ngx exec paperless-ngx \
  python3 manage.py drf_create_token -r agente-medico
```

The command prints the new token. Copy it directly into the agent's private
environment; do not store the terminal output or paste it into tickets, chat
or Git. Restart or reload the agent and confirm one read request succeeds.

Rotate after any suspected exposure, when the agent host changes and at least
once a year.

## Revoking access

Removing a user from `SYNC_READER_USERNAMES` does **not** revoke access:
`model-init` only adds view permissions with `merge` and never removes them.
To revoke:

1. Deactivate the user in Paperless, or delete its token (Django
   administration → Auth tokens) so no API request authenticates.
2. Remove its global permissions in Paperless.
3. Remove it from `SYNC_READER_USERNAMES`, delete the "Exámenes médicos"
   workflow and run `model-init` again, so the contract objects and the
   workflow no longer list it.

Object-level view permissions it kept on documents, tags and correspondents
do nothing once the account cannot authenticate; delete the user if they must
be removed as well.

## Isolation from other users

Since Sprint 019 a read-only user sees only the contract tags, the exam
owner's correspondents and the exams. Objects of other users, such as
[JuanchoAI](JUANCHOAI_ACCESS.md), are never shared with it, and
`reader-cleanup` removed the view rights granted on them by earlier runs (see
[Paperless Medical Sync](../../services/paperless-medical-sync/README.md#reader-cleanup)).
Custom field names remain visible to every user; their values are not (see
[Paperless Permission Findings](PAPERLESS_PERMISSIONS.md)).
