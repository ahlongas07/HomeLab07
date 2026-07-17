# Landing Page

## Purpose

Provide the first published service of HomeLab07.

This service validates the complete deployment workflow and serves as the reference implementation for future services published through Nginx Proxy Manager.

It also presents the current public platform status. During Sprint 005, the page was updated to reflect the collaboration platform milestone and OwnCloud availability.

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

- Nginx (official image)
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

Validate that the rendered page reflects the current platform milestone:

```text
v0.6.0-collaboration-platform
OwnCloud enabled
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

---

## Sprint

Implemented during:

- Sprint 001 – Foundation
- Sprint 003 – Zero Touch SSL
- Sprint 005 – Collaboration Platform status update
