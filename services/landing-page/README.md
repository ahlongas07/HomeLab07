# Landing Page

## Purpose

Provide the first published service of HomeLab07.

This service validates the complete deployment workflow and serves as the reference implementation for future services published through Nginx Proxy Manager.

It also presents the current public platform status and active Nextcloud,
Paperless-ngx, Jellyfin and Homebridge business services, plus the validated
Platform Operations security milestone and the encrypted Backup & Recovery
milestone, the validated Keycloak Identity Platform, and the Observability &
Alerting baseline. Homebridge is listed as a platform milestone only; the
service itself remains LAN-only.

---

## Responsibilities

- Welcome page
- Platform validation
- Nginx reference implementation
- Static content hosting
- Reverse proxy publication target
- Public status signal for platform milestones

---

## Technology

- Nginx `1.30.4-alpine` (official stable image)
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

The expected references are `nginx:1.30.4-alpine` and `nginx/1.30.4`.

Validate that the rendered page reflects the current platform milestone:

```text
Observability & Alerting
Metrics, logs + alerts
Observability and alerting
```

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

Nginx Proxy Manager should publish this service using:

```text
Forward Hostname / IP: homelab07-landing-page
Forward Port: 80
Scheme: http
```

Sprint 003 validation confirmed that the Landing Page is published through HTTPS by Nginx Proxy Manager.

---

## Internet Publication

Internet publication is managed by Nginx Proxy Manager as part of **Sprint 003**.

This service is intentionally limited to providing the internal HTTP endpoint and static content. It does not implement Internet exposure, HTTPS, DNS, or certificate management.

To keep this repository portable and secure, do not hardcode public IP addresses, domain names, or environment-specific values. Use placeholders in documentation and keep sensitive configuration outside the repository in `HomeLab07.private`.

---

## Security

This service contains no secrets.

Environment-specific configuration must never be committed to Git and belongs in `HomeLab07.private`.

The service must not expose public host ports directly.

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
