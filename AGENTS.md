# AGENTS.md

# Homelab07 - Agent Instructions

Welcome to Homelab07.

This repository contains an Infrastructure Engineering project focused on building a modern, reproducible and maintainable self-hosted platform.

This document provides guidance for AI coding agents and technical contributors.

---

# Repository Purpose

The repository is the single source of truth.

Production environments must never become the source of truth.

Every implementation should be reproducible from the repository.

---

# Read Before Making Changes

Always review these documents before making significant changes:

1. PROJECT_CHARTER.md
2. ENGINEERING_PRINCIPLES.md
3. PRODUCT_REQUIREMENTS.md
4. ROADMAP.md
5. The current Sprint document inside `/sprints`

These documents define the project's vision, engineering philosophy and current objectives.

---

# Engineering Priorities

When making decisions, prioritize:

1. Simplicity
2. Reliability
3. Maintainability
4. Security
5. Automation
6. Reproducibility

Avoid unnecessary complexity.

---

# Repository Rules

- Documentation is part of the deliverable.
- Infrastructure should be reproducible.
- Production must never be edited manually.
- Configuration belongs in version control.
- Keep changes focused and easy to review.
- Do not modify unrelated files.

---

# Security Rules

Never commit:

- Passwords
- API keys
- Secrets
- Certificates
- SSH keys
- Environment-specific configuration
- Production IP addresses
- Production domain names

Use placeholders and example files whenever possible.

Environment-specific information belongs only inside the local `private/` directory.

---

# Coding Guidelines

Prefer:

- Markdown for documentation.
- YAML for infrastructure configuration.
- Shell scripts for automation.

Keep implementations simple and readable.

---

# Git Guidelines

Create small, focused commits.

Preferred commit prefixes:

- feat:
- fix:
- docs:
- refactor:
- chore:

Example:

docs: improve roadmap

---

# Decision Framework

If multiple solutions are possible, choose the one that:

- Requires less maintenance.
- Improves reproducibility.
- Keeps infrastructure simple.
- Aligns with ENGINEERING_PRINCIPLES.md.
- Reduces operational effort.

---

# If You Are Unsure

Do not make assumptions.

Explain the available options, the trade-offs and recommend the solution that best follows the Engineering Principles.

---

# Final Principle

Homelab07 values engineering quality over implementation speed.

The objective is not only to build a working platform.

The objective is to build a platform that remains understandable, maintainable and reproducible for years.

## Pull Request Size

Each implementation task should be reviewable in less than 15 minutes.

If a task becomes larger than that, split it before implementation.

# Service README Standard

- Purpose
- Responsibilities
- Technology
- Directory Structure
- Validation
- Run
- Verification
- Security
- Related Sprint

## Source Control

The agent never commits, pushes or creates pull requests.

The agent prepares implementation changes and a commit summary.

The repository owner is responsible for Git history.
