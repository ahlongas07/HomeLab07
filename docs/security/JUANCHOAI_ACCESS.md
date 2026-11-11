# JuanchoAI Access

## Decision

JuanchoAI stores its quotes in Paperless-ngx with the dedicated user
`juanchoai`. Paperless holds two worlds that must never cross: the owner's
medical exams and JuanchoAI's documents. Isolation relies on object ownership:
each user sees only the objects it owns or that are shared with it.

Prepared by hand and verified by the project owner on 2026-10-30; Sprint 019
documents it and automates the verification. Since Sprint 020 the platform's
`paperless-quote-sync` service archives the quotes that the JuanchoAI API
writes to a NAS folder; see the
[quote archive specification](../../specs/quote-archive.md).

- The account is not superuser, staff or group member, and cannot delete
  documents, so a leaked token cannot remove documents or see exams.
- Accepted risk: the token grants access without a second factor; it is
  stored only as a secret in JuanchoAI's private environment and in the quote
  sync's private environment, and rotated as described below.
- `juanchoai` must never be added to `SYNC_READER_USERNAMES`: that list grants
  view access to exams.

## Account and permissions

| Setting | Value |
|---|---|
| User | `juanchoai`, active, token-only |
| Superuser, staff, groups | No, no, none |
| Document | `view_document`, `add_document`, `change_document` (no delete) |
| Tag, document type, custom field | `view_tag`, `view_documenttype`, `view_customfield` only |
| Anything else | None: no correspondents, tasks, users, workflows or mail |

Global permissions only allow the action; Paperless still applies object
ownership. `juanchoai` can view and change only the documents it owns, which
includes every document it uploads: Paperless makes the uploader the owner. It
cannot create tags, document types or custom fields; those are prepared by an
administrator.

Without `view_paperlesstask`, an upload cannot be confirmed through
`/api/tasks/`; see
[Paperless Permission Findings](PAPERLESS_PERMISSIONS.md#task-visibility-per-user).

## Objects and owners

| Object | Kind | Owner | Visible to |
|---|---|---|---|
| `Cotización` | Document type, matching "None" | `juanchoai` | `juanchoai` |
| `juanchoai` | Tag, matching "None" | `juanchoai` | `juanchoai` |
| `cotizacion-final` | Tag, matching "None" | `juanchoai` | `juanchoai` |
| `Work Item` | Custom field, text | None (custom fields have no owner) | Name visible to all users; values only with the document |
| Medical exams | Documents tagged `medico` | Exam owner (`SYNC_OWNER_USERNAME`) | Exam owner, `sync-medico`, read-only users; never `juanchoai` |
| Medical contract tags and type | Tags and `Examen médico` | Exam owner | Exam owner, `sync-medico`, read-only users |

Matching "None" keeps Paperless from assigning JuanchoAI tags or type to
other users' documents automatically. `model-init` never shares objects of
another owner with the medical read-only users and never reassigns them (see
[Paperless Medical Sync](../../services/paperless-medical-sync/README.md#read-only-users)).

## Verification

Run on the target host with the `juanchoai` token on stdin (hidden prompt on
a terminal; only counts are printed):

```bash
./operation/paperless-access-check.sh juanchoai
```

Expected result:

```text
PASS ISO-02 documents visible only its own: <n> visible, 0 not its own
PASS ISO-02 documents tagged 'medico': 0
PASS ISO-02 documents matching 'examen': 0
PASS ISO-03 /api/tags/ only its own: 2 visible, 0 not its own
PASS ISO-03 /api/document_types/ only its own: 1 visible, 0 not its own
PASS ISO-04 /api/tasks/ refused: HTTP 403
PASS ISO-04 /api/correspondents/ refused: HTTP 403
7/7 checks passed
```

`<n>` grows as quotes are archived; every visible document must be owned by
`juanchoai`, and the `medico` tag and `examen` searches must stay `0`.
Confirm the medical side with
`./operation/paperless-access-check.sh medical-reader` and the medical agent
token: `4/4 checks passed` (ISO-06). Repeat both after every `model-init` run,
every Paperless-ngx upgrade and the first quote upload.

## Quote folder and token consumers

Two containers use the `juanchoai` token, because Paperless allows one token
per user (accepted risk for the proof of concept):

| Consumer | Private environment | Reaches Paperless through |
|---|---|---|
| JuanchoAI API (verifies the archived document before DONE) | JuanchoAI's own private environment | `homelab07-internal`, `http://homelab07-paperless-ngx:8000`, no Cloudflare |
| `paperless-quote-sync` (uploads the PDFs) | `HomeLab07.private/env/paperless-quote-sync.env`, `PAPERLESS_QUOTE_TOKEN` | `homelab07-internal` |

The quote folder (`QUOTES_SOURCE_ROOT`) is owned by the platform operator user
and group with mode `750`; the API mounts it read-write and the sync read-only,
both running with the operator UID/GID. The API creates year subfolders with
`750` and files with `640`. No other service mounts it. The contract for the
files and their Paperless metadata is in the
[Paperless Quote Sync README](../../services/paperless-quote-sync/README.md#contract-with-juanchoai).

## Rotating the token

Regenerate the token, which invalidates the previous one:

```bash
./operation/compose.sh paperless-ngx exec paperless-ngx \
  python3 manage.py drf_create_token -r juanchoai
```

The command prints the new token. Copy it directly into JuanchoAI's private
environment and into `PAPERLESS_QUOTE_TOKEN` in
`HomeLab07.private/env/paperless-quote-sync.env`; do not store the terminal
output or paste it into tickets, chat or Git. Reload JuanchoAI, recreate the
sync with `./operation/compose.sh paperless-quote-sync up -d`, then run the
verification above with the new token.

Rotate after any suspected exposure, when the JuanchoAI host changes and at
least once a year.

## Revoking access

1. Deactivate `juanchoai` in Paperless, or delete its token (Django
   administration → Auth tokens) so no API request authenticates.
2. Remove its global permissions in Paperless.

Its documents, tags and document type keep `juanchoai` as owner and stay
invisible to the medical users. Reassign or delete them deliberately in
Paperless if JuanchoAI is retired.

## Related

- [Paperless Permission Findings](PAPERLESS_PERMISSIONS.md)
- [Medical Agent Access](MEDICAL_AGENT_ACCESS.md)
- [Sprint 019](../../sprints/SPRINT-019.md)
- [Sprint 020](../../sprints/SPRINT-020.md)
