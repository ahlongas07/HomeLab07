# Rockstor Observability Boundary

## Purpose

Rockstor remains the storage authority. HomeLab07 exports only the minimum
read-only evidence needed to correlate storage health with application and
operation failures.

## Inventory

The private tab-separated inventory contains:

```text
abstract-alias<TAB>absolute-mount<TAB>expected-filesystem
```

Aliases are stable roles such as `platform-data`; real shares, device serials,
UUIDs and paths must not appear in metrics or repository evidence.

## Checks

`operation/storage-metrics.sh` validates:

- `findmnt` resolves the exact configured mount target;
- filesystem type matches the private policy;
- mount options do not show read-only state;
- filesystem space and inode consumption;
- Btrfs allocation usage where readable;
- cumulative Btrfs device errors;
- last scrub result and age where readable.

An existing directory is not considered a mounted share. This prevents writes
from falling through to the operating-system filesystem after a mount failure.

## Privilege boundary

Alloy never receives Btrfs administration or host-root access. A reviewed
root-owned oneshot timer runs the fixed read-only adapter and atomically writes
`rockstor.prom`. The completed file is the only storage input visible to Alloy.

## Limitations

- SMART metrics remain excluded until a stable source is validated.
- Scrub timestamps depend on output supported by the installed Btrfs tools.
- Per-share logical usage is excluded because snapshots, reflinks and qgroups
  can make naive accounting misleading.
- Rockstor internal dashboard feeds and undocumented APIs are not scraped.

