# Security and policy

> Verified: 2026-11-24 · Source: `85d500f` · Proof: merged-source review and dated compatibility records

Never commit game data, signing material, provisioning profiles, credentials, pairing records, device identifiers, logs, captures, or generated validation reports. The original executable is never patched or re-signed. Do not add gameplay automation, anti-cheat or license workarounds, post-entry debugger attachment, or application-memory inspection beyond loading and verification.

Developer service, Local signing, and External JIT have separate executable-memory boundaries. Review an execution-mode change against its owning source, tests, and [Security](../../SECURITY.md).

## Experimental browser sign-in

The opt-in Forever browser-login path is off by default. This fork uses an isolated
persistent WebKit store to remember the official website session. WebKit owns its
cookies; Clear sign-in data removes that store's website data and the launch handoff.
Do not extract or export cookies, log credentials/callbacks/tickets, inject scripts,
bridge passwords, access desktop credentials, modify the executable or weaken
authentication. A remembered website session is sensitive local state, not a stored
reusable game-launch ticket.

A valid result stays in process memory until the immediate Forever start, then is handed to the game once through its required launch preferences. Clear those preferences after consumption, game return, timeout, disable, explicit clear, or process start. Tests must use fabricated tickets and isolated preference domains.

## Refresh when

Refresh after a security boundary, data-retention rule, execution mode, device protocol, or reporting route changes.
