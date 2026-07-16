# Cloudflare Dynamic DNS

## Purpose

Cloudflare Dynamic DNS keeps the public DNS records used by HomeLab07 synchronized with the current public IP address.

This is a platform enhancement, not an application-specific feature.

---

## Responsibilities

- Detect public IP changes.
- Update selected Cloudflare DNS records.
- Support Cloudflare-proxied publication.
- Keep DNS automation outside individual applications.
- Integrate with the HomeLab07 operation layer.

Cloudflare Dynamic DNS is not responsible for:

- Reverse proxy configuration.
- TLS certificate issuance.
- Application routing.
- Identity management.
- Database management.

---

## Technology

| Component | Technology |
|-----------|------------|
| Dynamic DNS | favonia/cloudflare-ddns |
| DNS Provider | Cloudflare |
| Runtime | Docker Compose |
| Operations | HomeLab07 operation layer |

The image uses the stable major tag:

```text
favonia/cloudflare-ddns:1
```

---

## Architecture Overview

Cloudflare Dynamic DNS belongs to the shared platform layer.

```text
Internet
   │
   ▼
Cloudflare DNS
   │
   ▼
Nginx Proxy Manager
   │
   ▼
Published Platform Services

──────────────────────────────────────────

Shared Platform Enhancements

Cloudflare Dynamic DNS
```

The service updates DNS records only. Public traffic still enters HomeLab07 through Nginx Proxy Manager.

---

## Directory Structure

Repository:

```text
services/cloudflare-ddns/
├── compose.yaml
├── README.md
└── .env.example
```

External private configuration:

```text
HomeLab07.private/
└── env/
    └── cloudflare-ddns.env
```

This service does not require persistent runtime storage.

---

## Environment Configuration

Environment variables are stored outside the Git repository.

Location:

```text
HomeLab07.private/env/cloudflare-ddns.env
```

Create the private environment file from the repository template:

```bash
mkdir -p ../HomeLab07.private/env
cp services/cloudflare-ddns/.env.example ../HomeLab07.private/env/cloudflare-ddns.env
```

Expected variables:

```dotenv
CLOUDFLARE_API_TOKEN=replace-with-cloudflare-api-token
CLOUDFLARE_DDNS_DOMAINS=example.com,www.example.com
CLOUDFLARE_DDNS_PROXIED=true
```

Real tokens and domain names must remain only in `HomeLab07.private`.

---

## Cloudflare API Token

Use a Cloudflare API token, not the global API key.

The token should be scoped to the minimum required permissions for the target zone.

Recommended permission:

```text
Zone / DNS / Edit
```

Restrict the token to the specific Cloudflare zone used by HomeLab07.

---

## Deployment

1. Create the private environment file:

```bash
mkdir -p ../HomeLab07.private/env
cp services/cloudflare-ddns/.env.example ../HomeLab07.private/env/cloudflare-ddns.env
```

2. Edit:

```text
HomeLab07.private/env/cloudflare-ddns.env
```

3. Validate the Compose configuration:

```bash
./operation/compose.sh cloudflare-ddns config
```

4. Start the platform:

```bash
./operation/start.sh
```

5. Check service status:

```bash
./operation/status.sh
```

---

## Operational Commands

HomeLab07 operations must go through the `operation/` layer.

```bash
./operation/start.sh
./operation/status.sh
./operation/stop.sh
./operation/compose.sh cloudflare-ddns config
./operation/compose.sh cloudflare-ddns logs
```

External automation should invoke these scripts instead of calling Docker Compose directly.

---

## Validation

Validate the following after deployment:

- Container starts successfully.
- Cloudflare API token is accepted.
- Public IP detection succeeds.
- Configured DNS records are updated.
- DNS records resolve to the current public IP.
- Cloudflare proxy status matches the intended configuration.
- Operation layer start, stop, and status commands work.

`CLOUDFLARE_DDNS_PROXIED=true` is the intended HomeLab07 default for managed records. Existing Cloudflare records should still be verified in Cloudflare after deployment.

---

## Backup

Cloudflare Dynamic DNS does not store persistent runtime data.

Back up the private environment file outside Git:

```text
HomeLab07.private/env/cloudflare-ddns.env
```

Do not copy API tokens into the repository.

---

## Restore

1. Restore the private environment file:

```text
HomeLab07.private/env/cloudflare-ddns.env
```

2. Start the service through the operation layer:

```bash
./operation/compose.sh cloudflare-ddns up -d
```

3. Validate logs and DNS resolution.

---

## Security

HomeLab07 follows a secure-by-default approach.

The following rules apply:

- Cloudflare API tokens remain outside Git.
- Real domain names remain outside Git.
- The container runs with a read-only filesystem.
- Linux capabilities are dropped.
- Privilege escalation is disabled.
- The service does not publish host ports.
- The service is not part of the reverse proxy network.

---

## Related Platform Enhancement

- Platform Enhancement — Cloudflare Dynamic DNS
- Introduced after Sprint 003 — Zero Touch SSL

This enhancement supports the public publication architecture established by Sprint 003 without coupling DNS automation to Nginx Proxy Manager or application services.
