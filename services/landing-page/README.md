# Landing Page

## Purpose

Provide the first published service of HomeLab07.

This service validates the complete deployment workflow and serves as the reference implementation for future services published through the shared reverse proxy.

The page presents only the HomeLab07 identity and its platform principles, in
Spanish, with light and dark themes. It deliberately does not list services,
technologies, versions or milestones: a public inventory of the platform helps
reconnaissance and has to be edited on every Sprint. The service inventory
lives in the repository and the Roadmap.

---

## Responsibilities

- Welcome page
- Platform validation
- Nginx reference implementation
- Static content hosting
- Reverse proxy publication target
- Browser security headers for its own content

---

## Technology

- Nginx `1.30.6-alpine` pinned by digest (official stable image)
- Docker Compose
- HTML
- CSS

---

## Directory Structure

```
landing-page/
├── compose.yaml
├── nginx.conf
└── html/
    ├── index.html
    ├── style.css
    └── assets/
        ├── favicon.svg
        ├── logo.svg
        └── imagen.webp
```

---

## Validation

Validate the Compose configuration through the operation layer:

```bash
./operation/compose.sh landing-page config
```

The command must complete without errors.

Confirm the deployed runtime uses the reviewed stable patch release:

```bash
docker inspect homelab07-landing-page \
  --format '{{.Config.Image}}'
docker exec homelab07-landing-page nginx -v
```

The expected references are `nginx:1.30.6-alpine@sha256:901e593c…` (the full
digest is in `compose.yaml`) and `nginx/1.30.6`.

Validate that the page and its assets return the security headers and that
Nginx does not announce its version:

```bash
docker exec homelab07-landing-page wget -qSO /dev/null http://127.0.0.1/
docker exec homelab07-landing-page wget -qSO /dev/null http://127.0.0.1/assets/imagen.webp
```

Both responses must include `Content-Security-Policy`,
`X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer`, and the
`Server` header must be `nginx` without a version. Repeat the request through
the public route to confirm that Caddy and the edge preserve them.

---

## Run

Start the platform:

```bash
./operation/start.sh
```

Verify that the container is running:

```bash
./operation/status.sh
```

---

## Network Access

The Landing Page does not publish host ports directly.

It is attached to the proxy network:

```text
homelab07-proxy
```

Caddy publishes this service from `services/caddy/sites/homelab07.caddy`
(`CADDY_LANDING_PAGE_DOMAIN` → `homelab07-landing-page:80`).

Sprint 003 validated HTTPS publication through the former proxy; Sprint 017
moved it to Caddy.

---

## Internet Publication

Internet publication is managed by the shared Caddy reverse proxy (Sprint 017).

This service is intentionally limited to providing the internal HTTP endpoint and static content. It does not implement Internet exposure, HTTPS, DNS, or certificate management.

To keep this repository portable and secure, do not hardcode public IP addresses, domain names, or environment-specific values. Use placeholders in documentation and keep sensitive configuration outside the repository in `HomeLab07.private`.

---

## Security

This service contains no secrets.

Environment-specific configuration must never be committed to Git and belongs in `HomeLab07.private`.

The service must not expose public host ports directly.

Nginx sends a strict Content Security Policy (`default-src 'self'`, no
framing, no forms, no base URI), `nosniff` and `no-referrer` on every
response, including errors, and hides its version (`server_tokens off`). The
page loads no scripts or external resources; any change that adds one must
update the policy. Locations in `nginx.conf` must not declare `add_header`,
or they stop inheriting these headers. HSTS is set by the shared Caddy route.

The page must not list services, technologies or versions of the platform.

The Landing Page has no persistent runtime state. Sprint 010 protects its
definition through the repository bundle and source snapshot.

---

## Sprint

Implemented during:

- Sprint 001 – Foundation
- Sprint 003 – Zero Touch SSL
- Sprint 005 – Collaboration Platform status update
- Sprint 006 – Document Management Platform status update
- Sprint 007 – Media Platform status update
- Sprint 008 – Homebridge Platform status update
- Sprint 009 – Platform Operations status update
- Sprint 010 – Backup & Recovery status update
- Sprint 011 – Identity Platform status update
- Sprint 013 – Observability & Alerting status update
- Sprint 014 – NAS Command Center status update
- Platform Enhancement – Landing page hardening (2026-11-13)
