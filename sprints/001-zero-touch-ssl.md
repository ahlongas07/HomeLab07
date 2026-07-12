# Sprint 001 - Zero Touch SSL

**Status:** In Progress

**Started:** 2026-07-11

---

# Objective

Eliminate manual SSL certificate management by introducing a centralized reverse proxy with automatic certificate renewal.

The final solution must allow application containers to operate without managing HTTPS certificates directly.

---

# Background

The current infrastructure requires manual intervention whenever SSL certificates expire or an application is upgraded.

Typical maintenance currently involves:

- Purchasing or renewing certificates.
- Copying certificates into containers.
- Modifying application configuration.
- Repeating the process after major upgrades.

These activities increase operational effort and introduce unnecessary technical debt.

---

# Success Criteria

This sprint will be considered complete when:

- HTTPS is managed by a reverse proxy.
- SSL certificates renew automatically.
- Application containers no longer manage certificates.
- OwnCloud upgrades no longer require SSL reconfiguration.
- The deployment process is fully documented.

---

# Scope

Included:

- Reverse Proxy
- Let's Encrypt
- Automatic Certificate Renewal
- OwnCloud Migration
- Deployment Documentation

Excluded:

- Paperless
- Dashboard
- Monitoring
- Backup Automation

---

# Current Architecture

```text
Internet
        │
     Router
        │
   Port Forwarding
        │
    OwnCloud
```

---

# Target Architecture

```text
Internet
        │
     Router
        │
Port Forwarding
        │
Reverse Proxy
        │
Docker Network
        │
    OwnCloud
```

---

# Engineering Decisions

## ED-001

A reverse proxy will terminate HTTPS connections.

Status:

✅ Approved

---

## ED-002

SSL certificates will no longer be managed by application containers.

Status:

✅ Approved

---

## ED-003

Persistent configuration will be stored outside containers.

Status:

✅ Approved

---

# Tasks

- [ ] Select reverse proxy solution
- [ ] Design Docker deployment
- [ ] Configure DNS
- [ ] Configure Dynamic DNS
- [ ] Deploy reverse proxy
- [ ] Configure HTTPS
- [ ] Validate certificate renewal
- [ ] Migrate OwnCloud
- [ ] Validate upgrade procedure
- [ ] Update documentation

---

# Validation

To be completed once implementation begins.

---

# Notes

This section records important observations made during the sprint.

---

# Lessons Learned

To be completed at the end of the sprint.

---

# Next Sprint

Infrastructure Standardization
