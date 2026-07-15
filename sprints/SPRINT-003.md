# Sprint 003 – Zero Touch SSL

**Version:** v0.4.0-zero-touch-ssl

**Status:** In Progress

---

# Objective

Provide secure public service publication through automatic HTTPS by introducing a centralized reverse proxy.

This sprint establishes the networking foundation of HomeLab07, allowing platform services to be securely exposed without embedding networking or certificate management inside individual applications.

---

# Scope

## In Scope

- Deploy Nginx Proxy Manager.
- Integrate with the shared MariaDB service.
- Automatic Let's Encrypt certificate management.
- HTTP → HTTPS redirection.
- Secure reverse proxy configuration.
- Centralized platform administration.
- Landing Page publication through Nginx Proxy Manager.
- Integration with the existing operation layer.
- Service documentation.

## Out of Scope

- Identity Provider.
- Single Sign-On.
- Forward Authentication.
- Cloudflare Tunnel.
- Wildcard certificates.
- DNS automation.
- Multiple domains.
- High Availability.
- Additional application deployment.

---

# Deliverables

Create:

```
services/nginx-proxy-manager/
```

Including:

- compose.yaml
- README.md
- .env.example

Persistent storage:

```
homelab07-data/

└── nginx-proxy-manager/
    ├── data/
    └── letsencrypt/
```

Integrate with:

- operation/start.sh
- operation/stop.sh
- operation/status.sh

Document:

- deployment
- configuration
- SSL management
- backup
- restore

---

# Dependencies

Requires:

- Sprint 001 — Foundation
- Sprint 002 — Data Foundation

---

# Deployment Prerequisites

Before deploying Nginx Proxy Manager, the required database resources must be created manually inside the shared MariaDB service.

This is an intentional architectural decision.

Database initialization is considered a one-time administrative task and therefore remains explicit rather than automated.

The complete procedure is documented in:

```
services/nginx-proxy-manager/README.md
```

Once the database has been initialized, Nginx Proxy Manager can be deployed using the standard HomeLab07 operational workflow.

---

# Storage Architecture

Persistent application data is stored inside the dedicated Rockstor Share.

```
homelab07-data/

├── mariadb/
│
└── nginx-proxy-manager/
    ├── data/
    └── letsencrypt/
```

Runtime state must never be stored inside the Git repository.

---

# Network Architecture

This sprint introduces the first public entry point of the platform.

```
                Internet
                    │
                    ▼
        Nginx Proxy Manager
                    │
     ┌──────────────┴──────────────┐
     ▼                             ▼
Landing Page              Future Services

──────────────────────────────────────────

        Shared Infrastructure

             MariaDB
```

All public traffic must enter the platform through Nginx Proxy Manager.

Platform services must never expose themselves directly to the Internet.

MariaDB belongs to the shared infrastructure layer and must never be published.

HomeLab07 standardizes two Docker networks.

```text
homelab07-internal
```

Private communication between platform services.

```text
homelab07-proxy
```

Traffic between the reverse proxy and published services.

The Landing Page becomes the first service published through `homelab07-proxy` and should no longer rely on direct public host port exposure.

---

# Security Requirements

The reverse proxy must:

- Redirect HTTP to HTTPS.
- Automatically obtain Let's Encrypt certificates.
- Automatically renew certificates.
- Publish only explicitly configured services.
- Keep all other platform services private by default.

MariaDB must remain accessible only through the internal Docker network.

---

# Operational Principles

Nginx Proxy Manager is a shared platform service.

Its lifecycle is managed exclusively through the HomeLab07 operation layer.

Supported operations:

- start
- stop
- status

Administrators should never interact directly with Docker unless performing diagnostics.

---

# Success Criteria

The sprint is complete when:

- Nginx Proxy Manager starts successfully.
- MariaDB connection succeeds.
- Application database credentials are loaded correctly.
- HTTPS certificates are issued automatically.
- Automatic certificate renewal is operational.
- Landing Page is published through HTTPS.
- HTTP requests redirect automatically to HTTPS.
- Configuration survives container recreation.
- Certificates survive container recreation.
- Landing Page no longer relies on direct public host port exposure.
- Persistent storage is validated.
- Operation layer integration is validated.
- Documentation is complete.

---

# Validation

Validate the following:

- Reverse proxy functionality.
- HTTPS connectivity.
- Automatic certificate issuance.
- Automatic certificate renewal.
- Container recreation.
- Persistent configuration.
- Persistent certificates.
- Landing Page proxy network integration.
- Internal Docker networking.
- Operation layer integration.

---

# Architecture Principles

This sprint reinforces the following permanent engineering principles.

- One reverse proxy for the entire platform.
- Infrastructure services remain application-agnostic.
- Applications own their own database resources.
- Persistent application data remains outside Git.
- Secrets remain outside Git.
- Platform operations remain centralized.
- Public exposure is always explicit.
- Security is the default configuration.
- Published services use the proxy network instead of publishing public ports directly.

---

# Risks

- DNS misconfiguration.
- Let's Encrypt rate limits.
- Incorrect proxy configuration.
- Database connectivity issues.
- Certificate issuance failures.
- Accidental exposure of internal services.

---

# Expected Outcome

At the end of this sprint HomeLab07 provides secure public publication of platform services through a centralized reverse proxy.

Applications no longer implement networking individually.

Instead, they consume the shared networking capabilities provided by the platform while remaining isolated, reproducible, and independently deployable.
