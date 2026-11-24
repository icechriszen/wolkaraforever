# Repository status

> Verified: 2026-11-24 · Source: `85d500f` · Proof: merged-source review and dated compatibility records

This downstream fork uses jklock as its primary upstream. Its default `main` branch
integrates the cumulative CN/iPhone implementation and refreshed documentation.
Runtime `b535ee4` was installed on the user's iPhone 17; the phone-tested snapshot
is `0a38398` and bundled WolkaraRoue is `1.0.5-cn.7`. Integration `85d500f` retains
those runtime/login/add-on sources and reconciles existing main-line logging and docs.
Do not treat an upstream tag as this fork's release number.

CN login, user-operated world entry, Standard touch/controller switching and Chinese
chat acceptance are recorded in `COMPATIBILITY.md`. Required simulator instances
were unavailable, and no Device Hub run or broad long-session pass is claimed.
Older experimental worktrees are not part of the published validated snapshot.

## Execution modes

- Developer service is the supported integrated route, and the mode `local.env.example` preselects. It is offered by the `Tolkara` build only.
- Local signing builds a local page container with the user's signing identity. It is offered by every build.
- External JIT is a diagnostics route offered by the `TolkaraDiagnostics` build (the unsigned `.ipa`). It requires an external JIT enabler and refuses guest entry while a debugger remains attached.

The project does not distribute game files, patch or re-sign game code, automate gameplay, inspect game memory beyond loading and verification, or claim universal device compatibility. User setup is documented in [Install WolkaraForever](../INSTALLATION.md).

## Refresh when

Refresh after a release, execution-mode change, repository-policy change, or change to the supported product boundary.
