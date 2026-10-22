# Recovery Matrix

| Service or capability | Persistent-state origin | Backup method | Restore order | Post-restore validation |
|---|---|---|---:|---|
| Repository | Git history and tracked source | Git bundle plus encrypted source snapshot | 1 | Revision, tag, clean status and script syntax |
| Private configuration | External private env, secrets and approved certificates | Encrypted Restic snapshot; password recovered independently | 2 | Owner-only permissions and required files present |
| MariaDB | Shared persistent database root | Logical all-database dump with applications quiesced | 3 | Import into disposable server, databases, grants and representative queries |
| Keycloak | Dedicated MariaDB database and private configuration | Logical all-database dump plus encrypted private configuration | 4 | Health, realm discovery, emergency administrator and OIDC client metadata |
| Nginx Proxy Manager | Data tree, certificates and MariaDB database | Stopped filesystem capture plus logical dump | 5 | Admin boundary, proxy hosts, certificates and representative HTTPS route |
| Nextcloud | `html`, `data` and MariaDB database | Maintenance mode, stopped filesystem capture and logical dump | 6 | `.ocdata`, ownership, users, shares, local login, OIDC and representative checksums |
| Paperless-ngx | Data, media, ingestion/export trees and MariaDB database | Stopped filesystem capture and logical dump | 7 | Sanity checker, originals, archives, search and download |
| Medical exam originals | Authoritative NAS folder (`SYNC_SOURCE_ROOT`) | NAS data backup; outside Restic scope | 8 | Restored from the NAS data backup with the same relative paths, before the sync starts; readable by the sync UID |
| Paperless Medical Sync | Repository source and private configuration; no persistent state (`tmpfs` only) | Repository plus encrypted private configuration | 9 | New `sync-medico` token, `up -d --build`, first run reports existing exams as skipped |
| Jellyfin | Configuration root | Stopped `/config` capture; cache excluded | 10 | Users, libraries, watched state, direct play and one transcode |
| Homebridge | Complete Homebridge state root | Stopped full-root capture | 11 | Isolated identity, accessories, automations and cameras without re-pairing |
| Landing Page | Repository source | Repository recovery only | 12 | Rendered milestone and HTTPS publication |
| Valkey | Transient memory | No runtime backup | 13 | Empty restart and application cache recovery |
| Dynamic DNS | Private configuration only | Encrypted private configuration snapshot | 14 | Container starts and reconciles DNS without exposing token values |

The numerical order is the normal dependency sequence. Incident scope may
permit restoring a single component, but its dependencies and matching recovery
point must still be validated.
