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

---

# Lessons Learned

## Technical

### Docker Permissions

The operational user must belong to the `docker` group to manage containers without requiring elevated privileges.

After updating group membership, a new login session is required before the changes take effect.

### Repository Structure

Separating `HomeLab07.private` from the Git repository proved to be a better long-term architectural decision.

The repository contains only version-controlled assets, while environment-specific configuration and sensitive information remain outside version control.

### Deployment Workflow

The deployment workflow was successfully validated:

```text
Developer Workstation
        ↓
Git Commit
        ↓
GitHub
        ↓
Runtime Environment
        ↓
git pull
        ↓
Docker Compose
        ↓
Running Service
```

This workflow will serve as the standard deployment process for all future services.

### Service Architecture

Keeping each service self-contained under `services/<service-name>/` simplifies maintenance, documentation, testing, and future deployments.

Each service owns:

- Docker Compose definition
- Runtime configuration
- Static assets
- Service documentation

---

## Engineering

### Documentation First

Investing time in documentation before implementation reduced ambiguity and helped maintain architectural consistency.

The combination of:

- AGENTS.md
- ENGINEERING_PRINCIPLES.md
- ROADMAP.md
- Sprint documentation

provided a clear implementation framework.

### Incremental Development

Implementing the sprint as a sequence of small, reviewable tasks produced higher-quality results than implementing the entire sprint at once.

### AI Collaboration

Using an AI coding agent as an implementation partner, while keeping architectural decisions and repository ownership under human review, resulted in better implementation quality and more consistent documentation.

The adopted workflow is:

```text
Architecture
        ↓
Implementation
        ↓
Review
        ↓
Documentation
        ↓
Commit
```

This process becomes the standard engineering workflow for HomeLab07.

---

## Sprint Outcome

Sprint 001 successfully established the operational foundation of HomeLab07.

The platform now provides:

- A reproducible deployment workflow.
- A standardized project structure.
- The first operational Docker service.
- A documented engineering process.

This milestone marks the transition from project planning to platform implementation.
