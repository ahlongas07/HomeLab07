# Landing Page

## Purpose

Provide the first public service of HomeLab07.

This service validates the complete deployment workflow and serves as the reference implementation for future services.

---

## Responsibilities

- Welcome page
- Platform validation
- Nginx reference implementation
- Static content hosting

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

Validate the Compose configuration:

```bash
docker compose config
```

The command must complete without errors.

---

## Run

Start the service:

```bash
docker compose up -d
```

Verify that the container is running:

```bash
docker compose ps
```

---

## Local Access

The service is expected to be available at:

```
http://localhost:8080
```

or

```
http://<NAS-IP>:8080
```

depending on the deployment environment.

---

## Internet Publication

Internet publication is validated as part of **Sprint 001** through the surrounding platform infrastructure, including Docker networking, router configuration, and future reverse proxy integration.

This service is intentionally limited to providing the HTTP endpoint and static content. It does not implement Internet exposure, HTTPS, DNS, or reverse proxy functionality. Those capabilities belong to the platform architecture and will be introduced in subsequent sprints.

To keep this repository portable and secure, do not hardcode public IP addresses, domain names, or environment-specific values. Use placeholders in documentation and keep sensitive configuration outside the repository in `HomeLab07.private`.

---

## Security

This service contains no secrets.

Environment-specific configuration must never be committed to Git and belongs in `HomeLab07.private`.

---

## Sprint

Implemented during:

- Sprint 001 – Foundation
