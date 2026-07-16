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

## Design Principles

Cloudflare Dynamic DNS follows the HomeLab07 platform design principles.

- One service, one responsibility.
- DNS synchronization is a platform capability, not application functionality.
- The service is stateless by design.
- Infrastructure remains application-agnostic.
- Secrets remain outside Git.
- Public DNS changes are centralized instead of duplicated across services.

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

Cloudflare Dynamic DNS belongs to the Platform Edge Layer.

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

Platform Edge Layer

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
├── env/
│   └── cloudflare-ddns.env
└── secrets/
    └── cloudflare-ddns-api-token
```

This service does not require persistent runtime storage.

---

## DNS Strategy

HomeLab07 uses one canonical DNS record managed by Dynamic DNS.

Recommended pattern:

```text
home.example.com      A      Managed by Cloudflare Dynamic DNS

media.example.com     CNAME  home.example.com
docs.example.com      CNAME  home.example.com
auth.example.com      CNAME  home.example.com
```

Only the canonical `A` record should normally be managed by this service.

Additional public services should usually be published as `CNAME` records pointing to the canonical endpoint. This minimizes DNS updates, simplifies future migrations, and keeps application publication independent from the public IP update mechanism.

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
CLOUDFLARE_API_TOKEN_FILE=/run/secrets/cloudflare_api_token
CLOUDFLARE_DDNS_DOMAINS=home.example.com
CLOUDFLARE_DDNS_PROXIED=true
CLOUDFLARE_DDNS_IP6_PROVIDER=none
CLOUDFLARE_DDNS_DETECTION_TIMEOUT=10s
```

`CLOUDFLARE_DDNS_DOMAINS` should normally contain the canonical endpoint only. Additional service names should usually be configured in Cloudflare as `CNAME` records pointing to that endpoint.

`CLOUDFLARE_DDNS_IP6_PROVIDER=none` disables IPv6 management. This is the recommended HomeLab07 default unless the network has working IPv6 end to end.

`CLOUDFLARE_DDNS_DETECTION_TIMEOUT=10s` gives public IP detection additional time on networks with occasional latency.

Real tokens and domain names must remain only in `HomeLab07.private`.

The Cloudflare API token is stored as a private secret file, not inline in the environment file:

```text
HomeLab07.private/secrets/cloudflare-ddns-api-token
```

Create it with:

```bash
mkdir -p ../HomeLab07.private/secrets
printf '%s' 'replace-with-cloudflare-api-token' > ../HomeLab07.private/secrets/cloudflare-ddns-api-token
chmod 600 ../HomeLab07.private/secrets/cloudflare-ddns-api-token
```

The secret file must contain only the token value, with no variable name and no extra newline requirement.

---

## Cloudflare API Token

Use a Cloudflare API token, not the global API key.

The token should be scoped to the minimum required permissions for the target zone.

Recommended permission:

```text
Zone / DNS / Edit
```

Restrict the token to the specific Cloudflare zone used by HomeLab07.

The managed DNS record must belong to a zone that exists in the same Cloudflare account where the token was created. If the service cannot find the zone, verify:

- The API token was copied correctly.
- The token has access to the target zone.
- The zone is active in Cloudflare.
- The configured domain belongs to that zone.
- The configured record exists or can be created by the token.

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

## Failure Scenarios

Expected recovery behavior:

| Scenario | Expected Behavior |
|----------|-------------------|
| Invalid API token | The container starts but DNS updates fail. Fix the token in `HomeLab07.private/secrets/cloudflare-ddns-api-token` and restart the service. |
| Public IP changes | The service detects the new public IP and updates the configured Cloudflare DNS record. |
| Cloudflare API temporarily unavailable | DNS updates fail temporarily. The container remains running and retries on the next update cycle. |
| No IPv6 connectivity | IPv6 management is disabled through `CLOUDFLARE_DDNS_IP6_PROVIDER=none`. |
| Slow public IP detection | Increase `CLOUDFLARE_DDNS_DETECTION_TIMEOUT` in the private environment file. |
| Container restart | The service starts again, reads the private environment file, detects the current public IP, and reconciles DNS. |
| Platform reboot | The operation layer starts the service with the platform. DNS is reconciled after the container starts. |

These scenarios should be validated through logs and DNS resolution after deployment.

---

## Backup

Cloudflare Dynamic DNS does not store persistent runtime data.

Back up the private environment file outside Git:

```text
HomeLab07.private/env/cloudflare-ddns.env
HomeLab07.private/secrets/cloudflare-ddns-api-token
```

Do not copy API tokens into the repository.

---

## Restore

1. Restore the private environment file:

```text
HomeLab07.private/env/cloudflare-ddns.env
HomeLab07.private/secrets/cloudflare-ddns-api-token
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

---

## Future Evolution

This enhancement establishes the foundation for future Platform Edge capabilities.

Potential future capabilities include:

- Cloudflare Zero Trust
- Web Application Firewall
- Rate Limiting
- Cloudflare Tunnel
- Advanced Edge Security

These capabilities are intentionally outside the scope of this enhancement.
