# Security Incident Response

## Principles

- Preserve application data and unrelated services.
- Change one reversible control at a time.
- Record sanitized timestamps and symptoms before remediation.
- Keep credentials, domains, addresses and provider identifiers outside Git.
- Use the HomeLab07 Operation Layer for container operations.

## Edge False Positive

1. Identify whether the Managed WAF, custom rule or rate-limit rule acted.
2. Preserve a sanitized event timestamp, action and rule class.
3. Disable only the implicated rule or narrow its exact match.
4. Repeat the affected application workflow.
5. Restore the last validated policy or document a bounded exception.

Do not disable the Cloudflare proxy for all applications as the first response.

## Lost Nginx Proxy Manager Administration

1. Confirm the operator is on an approved management network.
2. Confirm the container is running with `./operation/status.sh nginx-proxy-manager`.
3. Review sanitized logs with
   `./operation/compose.sh nginx-proxy-manager logs --tail=150`.
4. Restore the last validated router or host-firewall management rule.
5. Do not publish port 81 to WAN as a recovery shortcut.

## Unexpected Public Listener

1. Remove or disable the router forward first when safe.
2. Identify the owning service without exposing its address in repository logs.
3. Stop only that service through `./operation/stop.sh SERVICE` when containment
   is required.
4. Run `./operation/security-audit.sh` and preserve sanitized output.
5. Correct the Compose definition or document an approved exception before
   restoring service.

## Compromised Published Application

1. Disable its proxy host or edge route to isolate public access.
2. Keep database and storage services running unless evidence requires broader
   containment.
3. Preserve sanitized proxy, edge and application timestamps.
4. Rotate affected application credentials and tokens privately.
5. Recreate the application from repository definitions and validated state.
6. Re-enable publication only after regression and external-boundary tests pass.

## DNS API Token Exposure

1. Revoke the token at the provider.
2. Create a least-privilege replacement outside Git.
3. Replace the private secret file and verify restrictive permissions.
4. Restart only the Dynamic DNS service through the Operation Layer.
5. Confirm DNS updates without printing the token or real record values.

## Certificate Failure

1. Keep HSTS implications in mind; do not extend its duration during recovery.
2. Verify DNS path, port 80/443 reachability and Nginx Proxy Manager health.
3. Review renewal logs without copying certificate contents into Git.
4. Renew or restore the certificate through the existing proxy workflow.
5. Confirm hostname, chain and expiry before closing the incident.

## Return To Service

Run the repository audit, external negative tests and affected application
regression suite. Restore the exact policy in `EDGE_POLICY.md`, record sanitized
results, and create follow-up Sprint work for any temporary exception.
