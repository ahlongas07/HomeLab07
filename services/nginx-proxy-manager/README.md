# Nginx Proxy Manager

## Overview

Nginx Proxy Manager is the centralized reverse proxy for HomeLab07.

It provides:

- Reverse Proxy
- Automatic HTTPS
- Let's Encrypt integration
- Centralized service publication

---

# Dependencies

Requires:

- MariaDB (Sprint 002)

---

# Database Initialization

Before deploying Nginx Proxy Manager, create the application database inside the shared MariaDB service.

Connect to MariaDB:

```bash
docker exec -it homelab07-mariadb mariadb -u root -p
```

Create the database:

```sql
CREATE DATABASE npm_db;
```

Create the application user:

```sql
CREATE USER 'npm_user'@'%' IDENTIFIED BY '<strong-password>';
```

Grant privileges:

```sql
GRANT ALL PRIVILEGES ON npm_db.* TO 'npm_user'@'%';

FLUSH PRIVILEGES;
```

Verify:

```sql
SHOW DATABASES;

SELECT User, Host FROM mysql.user;
```

Store the credentials in:

```
HomeLab07.private/services/nginx-proxy-manager/.env
```

---

# Engineering Decision

HomeLab07 intentionally performs application database initialization manually.

Database creation is a one-time administrative activity.

Automating this step would introduce unnecessary platform complexity while providing little operational value.

MariaDB remains a generic infrastructure service.

Application-specific resources are created by each application administrator during deployment.

---

# Deployment

After completing the database initialization:

1. Configure `.env`.
2. Deploy using:

```bash
./operation/start.sh
```

3. Verify:

```bash
./operation/status.sh
```

4. Access the Nginx Proxy Manager administration interface.

---

# Persistent Storage

```
homelab07-data/

└── nginx-proxy-manager/
    ├── data/
    └── letsencrypt/
```

---

# Secrets

Application credentials must be stored only in:

```
HomeLab07.private/
```

---

# Validation

The deployment is considered successful when:

- NPM starts successfully.
- Connection to MariaDB succeeds.
- HTTPS certificates can be issued.
- Certificates survive container recreation.
- Configuration survives container recreation.
- Landing Page is published through HTTPS.
