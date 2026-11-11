# Paperless Permission Findings

Permission behaviors of Paperless-ngx 3.3.4 that affect how users are
isolated from each other. Observed by the project owner on 2026-10-30 while
preparing [JuanchoAI access](JUANCHOAI_ACCESS.md) (Sprint 019). Re-check them
when Paperless-ngx is upgraded.

## Task visibility per user

In Paperless-ngx 3.3.4, a user that is not a superuser and holds
`view_paperlesstask` saw the tasks of **every** user in `/api/tasks/`,
including the original file names of their uploads.

Re-checked on 3.4.1 (2026-11-05, Sprint 019 closure): a user that is not
staff sees only its own tasks and unowned tasks. API uploads are owned by the
uploader; unowned tasks are system tasks (mail fetch, classifier training,
workflow checks, trash and sanity checks) without upload file names.

Consequences:

- `juanchoai` does not hold `view_paperlesstask`; its token receives `403` on
  `/api/tasks/` (ISO-04).
- No new integration may depend on `/api/tasks/`. Confirm an upload by
  reading the documents the user owns instead.
- `sync-medico` holds `view_paperlesstask` because it confirms each upload
  through the task API (Sprint 015). Since 3.4.1 it no longer sees
  JuanchoAI's tasks. Its token is used only inside `homelab07-internal` by the
  sync container, has no public route and is stored only in the private
  environment file.
- Read-only users (`SYNC_READER_USERNAMES`) do not hold it.

## Custom fields have no owner

Custom fields are global objects without owner. Every user with
`view_customfield` sees the **names** of all custom fields, for example
`Ruta origen`, `Hash origen` and `Work Item`. The **values** belong to each
document and are visible only to users who can view that document.

Consequences:

- Never put personal or customer data in a custom field name.
- Custom fields are not listed by the `model-init` unowned-object warning:
  having no owner is their normal state.

## Unowned objects are visible to everyone

A document, tag, correspondent or document type without owner is visible to
every user that holds the global view permission for that model, including
`juanchoai`. `model-init` lists such objects at the end of each run (see
[Paperless Medical Sync](../../services/paperless-medical-sync/README.md#read-only-users));
assign them an owner in Paperless.

## Related

- [JuanchoAI Access](JUANCHOAI_ACCESS.md)
- [Medical Agent Access](MEDICAL_AGENT_ACCESS.md)
- [Sprint 019](../../sprints/SPRINT-019.md)
