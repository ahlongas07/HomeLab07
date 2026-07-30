# Platform Control Principles

## Purpose

This document defines control principles shared by every HomeLab07 capability.
Sprint documents inherit these requirements and should describe only the new
capability, its exceptions and its evidence.

## Security

- Deny exposure and privilege by default.
- Keep credentials, private paths, domains, addresses, certificates and
  environment identifiers outside Git.
- Use least privilege for users, tokens, networks, mounts and provider access.
- Separate source, private configuration, runtime state and recovery data.
- Treat encrypted data as sensitive and protect the corresponding keys through
  an independent recovery path.
- Document every exception with an identifier, owner, reason, validation and
  review trigger.

## Validation

Validation is layered:

1. static syntax and configuration rendering;
2. runtime health and expected topology;
3. positive application workflows;
4. negative access and failure tests;
5. recovery or rollback evidence;
6. sanitized completion record.

A configured control is not accepted until its effective behavior is tested.
Local configuration must not be presented as proof of an external boundary.

## State Preservation

- Determine authoritative state before changing a service.
- Quiesce writers when a consistent recovery point requires it.
- Preserve the matching repository revision, private configuration and runtime
  identity with persistent state.
- Restore only into a disposable or explicitly approved destination first.
- Never run duplicate network identities during recovery tests.
- Never delete the previous recovery point as part of rollback.

## Rollback

Every material change defines:

- the condition that triggers rollback;
- the last validated state;
- the minimum reversible action;
- the data that must remain untouched;
- the validation required after rollback.

Rollback must not depend on deleting persistent data, weakening unrelated
security controls or exposing an administrative interface publicly.

## Evidence

Evidence records outcomes, timestamps, versions, counts and control identifiers.
It excludes secrets, real endpoints, private paths, personal information and
application contents. Evidence must distinguish tested facts from assumptions
and deferred work.

## Acceptance

A capability is complete only when:

- documentation and reproducible configuration agree;
- required security boundaries are satisfied;
- static and target-runtime validation pass;
- normal workflows remain functional;
- failure, rollback and recovery paths are exercised proportionately to risk;
- operational ownership and review triggers are explicit;
- no private or environment-specific value enters Git.

Individual Sprints may strengthen these requirements but must not silently
weaken them.
