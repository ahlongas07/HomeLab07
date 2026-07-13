# Sprint 001 – First Public Service

**Status:** 🟡 In Progress

**Version:** v0.2.0-foundation

---

# Objective

Validate the complete HomeLab07 deployment pipeline by publishing the first containerized service.

The goal of this sprint is not to deploy a production service, but to verify that the engineering workflow defined during the Kickoff works end-to-end.

---

# Goals

- Deploy the first Docker container using Docker Compose.
- Serve a custom HomeLab07 landing page using Nginx.
- Validate the GitHub → NAS deployment workflow.
- Publish the service to the Internet.
- Prepare the foundation for reverse proxy and HTTPS automation in future sprints.

---

# Scope

Included:

- Nginx container
- Static landing page
- HomeLab07 branding
- Docker Compose
- Git deployment
- Internet publication

Not Included:

- HTTPS
- Reverse Proxy
- Cloudflare
- Authentication
- Monitoring
- Backups
- CI/CD

---

# Deliverables

## Repository Structure

```
services/
└── landing-page/
    ├── compose.yaml
    ├── nginx.conf
    └── html/
        ├── index.html
        ├── style.css
        └── assets/
            ├── logo.png
            └── favicon.ico
```

---

## Landing Page

The landing page must display:

- HomeLab07 logo
- Welcome message
- Project description
- Deployment status
- Current version

---

# Success Criteria

The sprint is considered complete when all of the following are true:

- [ ] Repository updated from GitHub
- [ ] `docker compose config` succeeds
- [ ] Nginx container starts successfully
- [ ] Landing page loads from the NAS
- [ ] Landing page is reachable from the local network
- [ ] Landing page is reachable from the Internet
- [ ] No sensitive configuration exists inside the Git repository

---

# Deployment Workflow

```
Developer
    │
    ▼
VS Code
    │
git commit
    │
git push
    ▼
GitHub
    │
git pull
    ▼
Rockstor
    │
docker compose up -d
    ▼
Nginx
```

---

# Risks

- Docker networking configuration
- Router port forwarding
- Firewall configuration
- DNS propagation (future)
- Volume permissions

---

# Engineering Principles Applied

- Simplicity First
- Git as Source of Truth
- Immutable Runtime
- Documentation First
- Small Incremental Changes

---

# Notes

This sprint intentionally focuses on validating the deployment pipeline instead of deploying production-grade services.

Every future service will follow the same deployment methodology validated in this sprint.

---

# Expected Outcome

A user should be able to access the HomeLab07 landing page from a web browser and verify that the platform deployment workflow is fully operational.

This marks the completion of the first operational milestone of HomeLab07.
