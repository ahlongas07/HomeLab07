# Nginx Proxy Manager Implementation Notes

Record upgrade decisions and sanitized target-host evidence here. Do not
record real domains, IP addresses, paths, credentials, certificate material or
proxy host names.

## Security Upgrade 2.15.1 → 2.16.0

Platform Enhancement prioritized for security on 2026-10-22.

| | Previous | Target |
|---|---|---|
| Tag | `jc21/nginx-proxy-manager:2.15.1` (tag only, no digest) | `jc21/nginx-proxy-manager:2.16.0` |
| Index digest | `sha256:52b2c59994f3d36acfcf70a1626f29734df0ed8c71bacc0269f78b6f939858bb` | `sha256:4393e642e233e5efd5adeb7f10918d4aaea71c9ed875b94190273fc8e87f9594` |
| amd64 manifest | `sha256:99a885f56ca2203a2eb352a5f9e2cd5c1e25786508debd725ad48ebe955d114f` | `sha256:57d85bffc776c01909c7b24e127a69a72b7d8c75d387e6cb26c762978fc43e4c` |
| arm64 manifest | `sha256:a36f72b9b4a44b7ca64ecdb80d903a635f9fe80bc01a1d68e0d4d4bd1e01b0d5` | `sha256:21554e198b039808b56690889e672bad316c4008767e648d846d99da9350afa8` |
| Upstream release | 2026-06-03 | 2026-09-24, latest stable on 2026-10-22 |

Digests were read from Docker Hub on 2026-10-22. The amd64 manifest matches
the image link in the official 2.16.0 release notes. The Compose definition
pins the multi-architecture index digest; record the runtime image identity on
the NAS.

### Security fixes included in 2.16.0

Reviewed against the official release notes and upstream commits:

- **CVE-2026-40519** (High; authenticated OS command injection through DNS
  provider credentials in `setupCertbotPlugins()`, affects 2.9.14–2.15.1).
  Fixed by upstream commit `a5db5ed` ("Changed order of escape to prevent
  RCE"), which is included in the `v2.16.0` tag. Requires a user with
  certificate management permission.
- Tokens issued before a password change are invalidated.
- 2FA QR codes are generated locally instead of by a third party.
- DNS provider credentials are removed from disk after certbot runs.
- Private key file permissions tightened; denied requests return `403`.
- Bundled components: OpenResty 1.31.1.1, certbot 5.8.0, s6-overlay 3.2.3.0.

### Known issues not fixed in any release on 2026-10-22

These affect 2.16.0 as well as 2.15.1, so the upgrade does not make them worse.
Upstream fixes exist only on the `develop` branch; HomeLab07 does not deploy
unreleased builds. Re-evaluate at the next release.

| Issue | Exposure in HomeLab07 | Mitigation |
|---|---|---|
| CVE-2026-93964 (Medium): certificate validation endpoint reachable without authentication (fixed upstream in PR #5946) | API is served on the administration port `81`, bound to the LAN address and not forwarded from WAN | Keep port `81` LAN-only and validate it with `docs/security/VALIDATION.md` |
| CVE-2026-102334: missing brute-force protection on login (reported through 2.16.0) | Administration port only | Same port `81` boundary; strong unique administrator password |
| CVE-2026-102335: improper authorization over `advanced_config` (reported through 2.16.0) | Only the platform administrator holds an NPM account | Do not create additional NPM users |
| Custom certificate private keys returned by the certificates API (fixed upstream in PR #5891) | Administrator session only | Same as above |
| Issue #5919: applying an access list, enabling a host or requesting a certificate can re-render a host without its `allow`/`deny` rules or SSL directives while the UI shows them as applied (fixed upstream in PR #5935) | Cloudflare-source-only access lists protect proxied hosts | `./operation/npm-access-audit.sh` before and after the upgrade and after every access-list, host-state or certificate change; failing hosts are blocked first (README, Access List and SSL Audit) |

Third-party CVE databases disagree on the fix state and exploitation status
of CVE-2026-93964, CVE-2026-102334 and CVE-2026-102335; the upstream
repository published no GitHub security advisory for them on 2026-10-22.

### Compatibility review

| Area | Finding |
|---|---|
| Database | Shared MariaDB through the `mysql2` driver and `DB_MYSQL_*` variables, unchanged. No new schema migration between 2.15.1 and 2.16.0; the changed migration files differ only in formatting |
| Administration port | Still `81` by default. 2.16.0 renders it from the optional `NPM_ADMIN_PORT`, which HomeLab07 does not set; the Compose port mapping is unchanged |
| Certificates | `/etc/letsencrypt` mount unchanged. Certbot moves to 5.8.0; upstream warns that DNS plugins may need dependency changes. HTTP-01 certificates are unaffected; confirm renewal of any DNS-01 certificate |
| Networks | `homelab07-internal` and `homelab07-proxy` unchanged. Listeners gain `reuseport`; `DISABLE_IPV6` still applies |
| Persistent data | `/data` and `/etc/letsencrypt` mounts unchanged. Start-up now also re-owns `/data/keys.json` |
| Health check | Uses the administration port as before |

Because the database schema does not change, the previous image can start on
the upgraded database. The supported rollback still restores the pre-upgrade
recovery point (see the README).

### Target result (2026-10-22)

Upgrade complete on the target host. Detailed evidence remains in the private
evidence location.

- Pre-upgrade recovery point created with 2.15.1 stopped. The backup's restart
  then recreated NPM with the new pin (the repository had been updated first);
  `backup.sh` has since been changed to restart containers without recreating
  them. Disposable restore and the WAN check of port `81` were confirmed by the
  project owner.
- Runtime image `jc21/nginx-proxy-manager:2.16.0@sha256:4393e642…`; no
  restart loop; database migration version unchanged (no new migration).
- `nginx -t` passes; no `.conf.err` file.
- Access audit identical before and after the upgrade: six active hosts, each
  with its access list rendered (rule count and `deny all`) and its
  certificate and HTTPS redirect; one warning for a host without Force SSL.
- Every published host answers through Cloudflare; direct origin requests are
  denied with `403`.
- Certbot renewal dry run passes for every certificate in use.
- Platform status clean.
- Security scan compared with the last 2.15.1 run on the private share; the
  upgrade removes most findings, and the two new high findings in certbot
  Python dependencies were accepted as not applicable to HTTP-01 validation.
- Follow-up: an expired certificate of a deleted host was deleted in the UI;
  its files remain on disk and its renewal keeps failing until removed.
  Enabling Force SSL on the remaining host is a separate decision.
