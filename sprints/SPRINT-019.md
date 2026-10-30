# SPRINT-019 — Paperless User Isolation

**Status:** Implemented in the repository — target rollout and validation
pending

**Classification:** Platform Enhancement

**Phase:** Phase 2 — Shared Platform Capabilities

**Depends On:** Sprint 015 medical records ingestion and its read-only users

## Objective

Paperless-ngx will hold two worlds that must never cross: the owner's medical
exams and JuanchoAI's documents. Correct `model-init` so the medical
read-only users only receive medical objects, clean up what earlier runs
shared, warn about unowned objects, and document and automate the isolation
that was prepared by hand.

## Scope

### Included

- R1: `grant_readers` shares only the tags managed by `model-init` (`medico`,
  `revisar-fecha`, `revisar-titulo` and the `SYNC_CATEGORY_MAP` categories)
  and the correspondents owned by `SYNC_OWNER_USERNAME`, and only the exam
  owner's documents tagged `medico`. It never touches objects of another
  owner. Unit tests.
- R2: one-off cleanup `reader-cleanup`: remove the read-only users from every
  tag and correspondent outside that scope and log how many objects changed.
- R3: `model-init` lists the documents, tags, correspondents and document
  types without owner and finishes with a warning.
- The two Paperless-ngx 3.3.4 findings in
  [`docs/security/PAPERLESS_PERMISSIONS.md`](../docs/security/PAPERLESS_PERMISSIONS.md).
- [`docs/security/JUANCHOAI_ACCESS.md`](../docs/security/JUANCHOAI_ACCESS.md):
  user, permissions, objects and owners, token rotation, verification.
- `operation/paperless-access-check.sh`: read-only token checks for ISO-02 to
  ISO-06.

### Excluded

- `paperless-quote-sync`, the quotes folder on the NAS and JuanchoAI Sprint
  008; they follow with their own specification.
- Revoking `view_paperlesstask` from `sync-medico` (recorded as an accepted
  risk).

### Prepared by hand on 2026-10-30 (documented, not repeated)

- The 82 medical documents are owned by the exam owner; `sync-medico` and
  `agente-medico` can view them; nobody else can change them.
- User `juanchoai`: active, no superuser, staff or groups; `view_document`,
  `add_document`, `change_document`; `view_tag`, `view_documenttype`,
  `view_customfield`; nothing else.
- Document type `Cotización` and tags `juanchoai` and `cotizacion-final`, with
  matching "None" and owner `juanchoai`; custom field `Work Item` (text).
- The `juanchoai` token, stored as a secret.
- Verified with that token: 0 documents, only its 2 tags and `Cotización`,
  `403` on correspondents and tasks.

## Requirements and acceptance criteria

- **Given** a tag or correspondent of another owner, or without owner, **when**
  `model-init` runs with read-only users, **then** it is neither shared nor
  changed.
- **Given** another owner holds a tag named like a contract tag, **when**
  `model-init` runs, **then** that tag keeps its owner and permissions and
  `model-init` creates its own.
- **Given** read-only users with view rights on non-medical objects from
  earlier runs, **when** `reader-cleanup` runs, **then** only those users are
  removed, every other user, group and owner is kept, the count is logged, and
  a second run changes `0`.
- **Given** objects without owner, **when** `model-init` runs, **then** it
  lists them by id and ends with `Data model ready with warnings`.

| ID | Verification | Expected |
|---|---|---|
| ISO-01 | Unit test: tag and correspondent of another owner | `grant_readers` does not share them |
| ISO-02 | `juanchoai` token: `/api/documents/` and `?query=examen` | `0` |
| ISO-03 | `juanchoai` token: `/api/tags/` and `/api/document_types/` | Only its own |
| ISO-04 | `juanchoai` token: `/api/tasks/` and `/api/correspondents/` | `403` |
| ISO-06 | `agente-medico` token: `/api/tags/` | No JuanchoAI tag appears |
| ISO-08 | Run the deployed `model-init`, repeat ISO-02 to ISO-06 | Same result |
| ISO-09 | Medical agent validation | 12/12 |

ISO-02 to ISO-04 run with `paperless-access-check.sh juanchoai`; ISO-06 with
`paperless-access-check.sh medical-reader`, which also requires every visible
tag and correspondent to belong to the exam owner.

## Architecture and security contracts

- Isolation relies on Paperless object ownership; no new service, route or
  network.
- `model-init` and `reader-cleanup` use a temporary superuser token read from
  stdin and deleted afterwards. The access check reads the user token from
  stdin, sends it only to Paperless-ngx inside its container and prints only
  counts.
- `juanchoai` is never a medical read-only user.
- Paperless-ngx 3.3.4 shows every user's tasks to any non-superuser with
  `view_paperlesstask`; `juanchoai` lacks it, and no integration may depend
  on `/api/tasks/`. `sync-medico` keeps it and sees JuanchoAI's tasks (accepted
  risk, see the findings).

## Rollout

Blocking: nobody runs `model-init` until the image from this Sprint is
deployed; the previous image shares every tag and correspondent with the
read-only users.

1. Run the tests locally (`python3 -m unittest discover -s
   services/paperless-medical-sync/tests`).
2. On the target host, after the change is in the repository checkout:

   ```bash
   ./operation/compose.sh paperless-medical-sync build
   ./operation/compose.sh paperless-medical-sync up -d
   ```

3. Baseline: run `./operation/paperless-access-check.sh juanchoai` and
   `./operation/paperless-access-check.sh medical-reader`.
4. Create a temporary superuser token and run `reader-cleanup`; record the
   count. Run it again and confirm `0 objects changed`.
5. With the same token run `model-init`; record any unowned-object warnings.
   Delete the temporary token.
6. ISO-08: repeat both access checks; expect `6/6` and `4/4`.
7. ISO-09: run the medical agent validation; expect 12/12.

## Rollback

Set the image back to `homelab07/paperless-medical-sync:sprint-015` in
`compose.yaml` and run `up -d`; that image stays on the host. Do not run
`model-init` with it afterwards: it would share every tag and correspondent
with the read-only users again. Permissions removed by `reader-cleanup` were
not part of the read-only contract; re-grant one by hand in Paperless only if
it was intended.

## Closure record

### Repository validation (2026-10-30)

- `py_compile` and 20 standard-library tests pass, including 6 new tests for
  ISO-01, same-named tags of another owner, adopting an unowned contract tag,
  `reader-cleanup` and the unowned-object warning.
- The access check passes `bash -n`; run on the target host with an invalid
  token, it fails closed (`0/6`, `0/4`, every request `HTTP 401`).
- Paperless-ngx 3.3.4 source on the target host confirms that `set_permissions`
  on update replaces the given users without changing the owner, and that
  `full_perms` returns user ids.

### Residual work

- Target rollout steps 2 to 7 and their sanitized results.
- Update the medical records specification status once ISO-08 and ISO-09
  pass.

Detailed private evidence remains in its approved private location.
