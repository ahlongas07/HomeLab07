# Security Validation

## Repository Audit

Run from the repository root:

```bash
./operation/security-audit.sh
```

The command is read-only, emits sanitized counts and classifications, and
returns non-zero when a required control fails. Warnings identify documented
exceptions or checks that require external evidence. It does not prove router,
firewall or provider state.

## External Boundary

Perform tests from a network that is not the approved management LAN:

1. Confirm only HTTP and HTTPS reach the public gateway.
2. Confirm the Nginx Proxy Manager administration port is unreachable.
3. Confirm each proxied hostname returns an edge server header and request ID.
4. Resolve a proxied hostname directly to the origin and confirm denial.
5. Confirm DNS-only media remains functional through HTTPS without claiming
   edge protection.

Keep real hostnames and addresses in private operational evidence. Repository
results should record only pass/fail status and timestamp.

## Application Regression

After each edge-policy change, validate:

- browser login and logout;
- collaboration browser and native-client synchronization;
- WebDAV and representative upload/download operations;
- document upload, processing, viewing and download;
- media login, browsing, range requests, WebSockets and playback;
- Landing Page navigation;
- HomeKit discovery, representative automations and cameras from the LAN.

## Header And TLS Checks

For a placeholder proxied hostname:

```bash
curl -sI "https://HOSTNAME.example.invalid/?validation=TIMESTAMP" |
  grep -Ei 'HTTP/|server:|cf-ray|strict-transport-security|referrer-policy|x-content-type-options'
```

Expected policy values:

```text
x-content-type-options: nosniff
referrer-policy: strict-origin-when-cross-origin
strict-transport-security: max-age=2592000
```

Each security header must appear once. HTTP must redirect to HTTPS. Certificate
hostname, chain, expiry and renewal must remain valid.

## Rate-Limit Validation

Confirm ordinary login succeeds before and after the rule is enabled. Use a
controlled request sequence without credentials to cross the configured
threshold, confirm the temporary block, then confirm recovery after 10 seconds.
Do not load-test the application or include credentials in evidence.

## Validation Record

Record only:

- date and policy revision;
- tester role, not personal identifiers;
- sanitized control name;
- pass, warning or failure;
- rollback exercised and outcome;
- follow-up owner and review trigger.
