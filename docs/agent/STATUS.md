# Repository status

> Verified: 2026-11-23 · Source: `0a38398` · Proof: source review and dated compatibility records

This downstream fork uses jklock as its primary upstream. The published
`integration/cn-ios-validated` branch contains the cumulative tested local changes;
`docs/cn-ios-guide` adds documentation only. Runtime `b535ee4` was installed on the
user’s iPhone 17; the source snapshot is `0a38398` and bundled WolkaraRoue is
`1.0.5-cn.7`. Do not treat an upstream tag as this fork’s release number.

CN login, user-operated world entry, Standard touch/controller switching and Chinese
chat acceptance are recorded in `COMPATIBILITY.md`. Required simulator instances
were unavailable, and no Device Hub run or broad long-session pass is claimed.
Older experimental worktrees are not part of the published validated snapshot.

## Execution modes

- Developer service is the supported integrated route.
- Local signing builds a local page container with the user's signing identity.
- External JIT is a diagnostics route that requires an external JIT enabler and refuses guest entry while a debugger remains attached.

The project does not distribute game files, patch or re-sign game code, automate gameplay, inspect game memory beyond loading and verification, or claim universal device compatibility. User setup is documented in [Install WolkaraForever](../INSTALLATION.md).

## Refresh when

Refresh after a release, execution-mode change, repository-policy change, or change to the supported product boundary.
