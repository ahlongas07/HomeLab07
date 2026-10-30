# JuanchoAI Access

## Decision

JuanchoAI stores its quotes in Paperless-ngx with the dedicated user
`juanchoai`. Paperless holds two worlds that must never cross: the owner's
medical exams and JuanchoAI's documents. Isolation relies on object ownership:
each user sees only the objects it owns or that are shared with it.

Prepared by hand and verified by the project owner on 2026-10-30; Sprint 019
documents it and automates the verification. The JuanchoAI integration that
uploads quotes (`paperless-quote-sync`) is out of scope and will define its own
route, client requirements and specification.

- The account is not superuser, staff or group member, and cannot delete
  documents, so a leaked token cannot remove documents or see exams.
- Accepted risk: the token grants access without a second factor; it is
  stored only as a secret in JuanchoAI's private environment and rotated as
  described below.
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
[Paperless Permission Findings](PAPERLESS_PERMISSIONS.md#tasks-are-not-isolated-per-user).

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
PASS ISO-02 documents visible: 0
PASS ISO-02 documents matching 'examen': 0
PASS ISO-03 /api/tags/ only its own: 2 visible, 0 not its own
PASS ISO-03 /api/document_types/ only its own: 1 visible, 0 not its own
PASS ISO-04 /api/tasks/ refused: HTTP 403
PASS ISO-04 /api/correspondents/ refused: HTTP 403
6/6 checks passed
```

The document count is `0` while JuanchoAI has uploaded nothing; afterwards
only `documents matching 'examen'` must stay `0`. Confirm the medical side with
`./operation/paperless-access-check.sh medical-reader` and the medical agent
token: `4/4 checks passed` (ISO-06). Repeat both after every `model-init` run
and every Paperless-ngx upgrade.

## Rotating the token

Regenerate the token, which invalidates the previous one:

```bash
./operation/compose.sh paperless-ngx exec paperless-ngx \
  python3 manage.py drf_create_token -r juanchoai
```

The command prints the new token. Copy it directly into JuanchoAI's private
environment; do not store the terminal output or paste it into tickets, chat
or Git. Reload JuanchoAI, then run the verification above with the new token.

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
