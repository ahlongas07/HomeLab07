# AGENTS.md

# HomeLab07 - Agent Instructions

Welcome to HomeLab07.

This repository contains an Infrastructure Engineering project focused on building a modern, reproducible and maintainable self-hosted platform.

This document defines how AI engineering agents should contribute to the project.

The objective is not only to generate code, but to preserve the engineering quality, architecture and long-term maintainability of the platform.

---

# Engineering Contract

The AI agent acts as an Engineering Contract for HomeLab07.

This means the agent is responsible for helping preserve the project's engineering intent while implementing, reviewing and documenting changes.

The agent must:

- Understand the active Sprint before implementation.
- Protect the repository as the single source of truth.
- Keep infrastructure reproducible from version-controlled assets.
- Preserve the separation between source code, secrets and persistent data.
- Prefer platform capabilities over application-specific shortcuts.
- Improve the platform as a whole, not only the immediate implementation.
- Build reusable platform capabilities before application-specific functionality whenever possible.
- Keep changes focused, reviewable and aligned with the current Sprint.
- Document implementation decisions as part of the deliverable.
- Validate changes whenever practical before reporting completion.
- Explain trade-offs clearly when multiple solutions are possible.

The agent must not:

- Treat production as the source of truth.
- Encode local secrets, domains, public IPs or environment-specific values in the repository.
- Introduce new platform capabilities outside the approved scope without first explaining the trade-offs.
- Optimize for speed at the cost of maintainability, security or reproducibility.

The agent's role is not only to make the requested change.

The agent's role is to help HomeLab07 remain understandable, maintainable and reproducible over time.

---

# Repository Purpose

The repository is the single source of truth.

Production environments must never become the source of truth.

Every implementation must be reproducible from the repository.

Documentation is considered part of the product.

---

# Read Before Making Changes

Before making significant changes, always review:

1. PROJECT_CHARTER.md
2. ENGINEERING_PRINCIPLES.md
3. PRODUCT_REQUIREMENTS.md
4. ROADMAP.md
5. The active Sprint document under `/sprints`

These documents define the project vision, architecture and current implementation priorities.

---

# Engineering Priorities

When multiple solutions are possible, prioritize:

1. Simplicity
2. Reliability
3. Maintainability
4. Security
5. Automation
6. Reproducibility

Avoid unnecessary complexity.

Every engineering decision should reduce long-term operational effort.

---

# Architecture Principles

HomeLab07 is built as a reusable infrastructure platform.

Infrastructure capabilities should remain reusable by all platform applications.

Applications should consume platform services rather than implementing infrastructure individually.

Examples include:

- Shared MariaDB
- Shared Reverse Proxy
- Shared Identity Provider
- Shared DNS
- Shared Operations Layer

Shared infrastructure components must remain application-agnostic whenever possible.

Engineering decisions should improve the platform as a whole, not only the immediate implementation.

Whenever possible, build reusable platform capabilities before application-specific functionality.

---

# Repository Rules

- Documentation is part of every implementation.
- Infrastructure must remain reproducible.
- Production environments must never be edited manually.
- Configuration belongs in version control.
- Keep implementations focused and easy to review.
- Do not modify unrelated files.
- Every change should strengthen the platform rather than solving only one application's problem.

---

# Sprint Discipline

Every implementation must belong to one of the following:

- Approved Sprint
- Platform Enhancement
- Documentation Improvement
- Bug Fix

Do not introduce additional platform capabilities outside the approved scope.

If additional improvements are identified, propose them as future Sprint work rather than implementing them immediately.

Maintain focus on completing the current Sprint.

---

# Security Rules

Never commit:

- Passwords
- API Keys
- Secrets
- Certificates
- Private Keys
- SSH Keys
- Environment-specific configuration
- Production IP addresses
- Production domain names

Always use placeholders and example configuration files.

Environment-specific information belongs only inside:

```
HomeLab07.private/
```

The agent MUST NEVER modify:

- HomeLab07.private/
- Local environment files
- Certificates
- SSH private keys

unless explicitly instructed.

Infrastructure services must never be exposed publicly unless explicitly required by the current Sprint.

---

# Service Architecture

Each infrastructure service owns its own:

- Documentation
- Configuration
- Persistent storage
- Operational procedures
- Validation procedure

Infrastructure services should remain independent whenever possible.

Shared services should not contain application-specific configuration.

---

# Service README Standard

Every service README should include:

- Purpose
- Responsibilities
- Technology
- Directory Structure
- Configuration
- Deployment
- Validation
- Backup
- Restore
- Security
- Related Sprint

Documentation should be updated as part of the implementation.

---

# Coding Guidelines

Prefer:

- Markdown for documentation.
- YAML for infrastructure configuration.
- Shell scripts for automation.

Implementations should remain:

- Simple
- Readable
- Maintainable
- Self-documenting

---

# Validation Requirements

Before creating a commit, validate the implementation whenever applicable.

Examples include:

- docker compose config
- operation/status.sh
- YAML validation
- Markdown validation
- Shell script syntax validation

If validation fails:

- Explain the issue.
- Do not commit until the implementation is consistent.

Validation is part of the Definition of Done.

---

# Source Control Workflow

The AI agent is considered an engineering contributor, but repository ownership remains with the project owner.

The agent MAY:

- Modify repository files.
- Prepare focused implementation changes.
- Prepare commit summaries.
- Recommend commit messages.
- Review diffs and identify risks.
- Explain what should be committed.

The agent MUST NOT:

- Commit changes.
- Push changes.
- Push directly to `main`.
- Rewrite Git history.
- Force push.
- Delete branches.
- Delete tags.
- Create releases unless explicitly instructed.

Every commit should represent one logical engineering change.

Commits should remain small enough to be reviewed in less than 15 minutes.

Preferred commit prefixes:

- feat:
- fix:
- docs:
- refactor:
- chore:

Examples:

```
feat: implement nginx proxy manager

docs: update sprint 004

fix: correct docker networking

refactor: simplify operation scripts
```

---

# Decision Framework

If multiple solutions are possible, choose the one that:

- Requires less maintenance.
- Improves reproducibility.
- Keeps infrastructure simple.
- Aligns with ENGINEERING_PRINCIPLES.md.
- Reduces operational effort.
- Improves platform reusability.

The simplest correct solution is usually preferred.

---

# If You Are Unsure

Do not make assumptions.

Instead:

- Explain the available options.
- Describe the trade-offs.
- Recommend the solution that best aligns with the Engineering Principles.
- Wait for approval before making architectural changes.

---

# Definition of Done

An implementation is complete only when:

- Documentation is updated.
- Configuration is reproducible.
- Validation succeeds.
- Security requirements are satisfied.
- Operational procedures are documented.
- The implementation aligns with the current Sprint.

---

# Final Principle

HomeLab07 values engineering quality over implementation speed.

The objective is not merely to build working services.

The objective is to evolve HomeLab07 as a reusable infrastructure platform where every implementation strengthens the platform rather than solving a single application problem.

Every Sprint should leave the platform:

- Simpler
- Better documented
- Easier to maintain
- Easier to reproduce
- More secure

Build • Host • Automate
