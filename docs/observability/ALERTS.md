# Observability Alert Runbooks

Alerts identify conditions requiring review. They never authorize automatic
remediation. Preserve evidence before restarting or modifying a service.

## Approved endpoint unavailable

1. Confirm the failure from a second approved LAN client.
2. Check the endpoint's proxy, TLS and owning service status.
3. Compare dependencies in the Applications dashboard.
4. Do not treat a running container as proof that the application is healthy.

## Batch operation failed or stale

1. Compare last run, last success and last status.
2. Inspect the owning operation's sanitized terminal or systemd status.
3. Confirm the textfile directory remains mounted and writable by the producer.
4. Run the operation manually only after checking for an existing lock.

## Backup stale

1. Do not apply retention.
2. Run backup preflight and identify the last validated recovery point.
3. Correct the primary failure and create a new recovery point.
4. Complete integrity and disposable-restore validation.

## Security scan stale

1. Confirm report and cache shares are available.
2. Run scanner preflight.
3. Correct runtime, capacity or registry errors before starting another scan.
4. Keep detailed evidence private.

## Expected storage mount invalid

1. Stop writers that target the affected path.
2. Verify `findmnt` target, source, filesystem and options on the host.
3. Diagnose and restore the share through Rockstor.
4. Confirm the exact mount before restarting applications.

Never write test data into an unverified mount path.

## Storage pressure

1. Evaluate filesystem space pressure first. Use Btrfs data and metadata
   allocation only as diagnostic context because it describes allocated chunks,
   not total free filesystem capacity. Treat inode values as diagnostic only
   for filesystems with a fixed inode model.
2. Review snapshots and Rockstor allocation before deleting anything.
3. Do not assume logical share size equals physical Btrfs consumption.
4. Use an approved capacity or retention action.

## Btrfs critical state

1. Stop avoidable write workloads.
2. Review Rockstor and `btrfs device stats` without resetting counters.
3. Confirm whether the filesystem became read-only.
4. Preserve backup and recovery evidence before repair activity.

## External security scan target failed

1. HomeLab07 evidence from the same run is complete; this alert concerns only
   the named target.
2. Read the target's failure stage in the run's `summary.md` or `manifest.json`.
3. Run scanner preflight to see the target's definition, repository, shallow
   clone, Compose or exception problem.
4. For a missing local image, ask the application owner to build it; do not
   build or deploy external applications from the platform.
5. The alert resolves after the next scan in which the target succeeds.

## Gitleaks findings

1. Identify the target from the alert, then review only the restricted
   security report under `repository/<target>/`.
2. Classify the finding without publishing matched content.
3. Rotate a real credential before repository cleanup.
4. Follow incident response; do not rewrite history without approval.

## Certificate expiry

1. Confirm the certificate and endpoint through the approved proxy path.
2. Review Caddy's certificate maintenance in `docker logs homelab07-caddy`:
   HTTP-01 must reach the origin through Cloudflare on port 80.
3. Caddy renews automatically; correct the cause and reload or restart it.
4. Revalidate the externally served chain and expiry.

## Host resource pressure

1. Confirm the condition persisted for the full alert interval.
2. Compare CPU, memory, swap and load with endpoint latency.
3. Identify the workload through host tools without granting Alloy process or
   Docker access.
4. Preserve application availability and investigate before restarting.
