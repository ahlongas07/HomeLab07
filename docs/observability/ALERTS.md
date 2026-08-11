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

1. Compare filesystem, inode, Btrfs data and Btrfs metadata pressure.
2. Review snapshots and Rockstor allocation before deleting anything.
3. Do not assume logical share size equals physical Btrfs consumption.
4. Use an approved capacity or retention action.

## Btrfs critical state

1. Stop avoidable write workloads.
2. Review Rockstor and `btrfs device stats` without resetting counters.
3. Confirm whether the filesystem became read-only.
4. Preserve backup and recovery evidence before repair activity.

## Gitleaks findings

1. Review only the restricted security report.
2. Classify the finding without publishing matched content.
3. Rotate a real credential before repository cleanup.
4. Follow incident response; do not rewrite history without approval.

## Certificate expiry

1. Confirm the certificate and endpoint through the approved proxy path.
2. Review NPM renewal status and DNS challenge behavior.
3. Renew through the existing certificate lifecycle.
4. Revalidate the externally served chain and expiry.

## Host resource pressure

1. Confirm the condition persisted for the full alert interval.
2. Compare CPU, memory, swap and load with endpoint latency.
3. Identify the workload through host tools without granting Alloy process or
   Docker access.
4. Preserve application availability and investigate before restarting.
