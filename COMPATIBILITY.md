# Compatibility and support boundary

> Verified: 2026-11-13 · Source: `3c33543`

WolkaraForever is a source-built project for an iPad or iPhone that you own and configure with your own Apple Developer account. The supported integrated route requires Developer Mode, current Xcode tooling, and an execution path that can prepare executable memory.

## Supported boundary

The project supports the Forever lifecycle and features described in the current user guide. Its reviewed simulator layouts are iPhone Duo and iPad Pro 13-inch (M5).

## Not guaranteed

WolkaraForever does not promise universal device, iOS-version, controller, network, account, or game-client compatibility. It does not provide an App Store build, game distribution, gameplay automation, game-code modification, integrity bypasses, or account-safety guarantees.

**Battle.net Login (Experimental)** is an opt-in compatibility path, not a supported replacement for normal in-game login. The in-app browser keeps an isolated website session across launches; Clear sign-in data removes it. Each launch result is single-use and transient. The feature may stop working without notice. Use it at your own risk.

**Login and the system roots.** The game validates Battle.net's certificate against macOS's system root certificates, which every artifact this project's toolchain builds supplies. An app installed by another route, or built without them, cannot log in in any execution mode: the client answers `BLZ51900003` with the experimental login on and off. [Use WolkaraForever on iPhone](docs/IPHONE.md) says how to check a build.

## Physical validation: iPhone 17, 2026-11-22

Installed source `ce882b0`, iOS 27.2.1, Developer service, CN Forever
1.60.1.71037, with host lifetime diagnostics enabled:

- The isolated C++ string/thread adapter was active: 49 imports resolved through it,
  and both allocation and release paths ran. The Mac regression requires the former
  resolver to fail and the corrected resolver to pass; strings completed 8/8 tracked
  allocations/releases and threads/futures 49/49, with no foreign release or outstanding
  tracked allocation. ASan/UBSan and host-allocation isolation checks passed.
- The installed app reused the in-app CN website session and accepted the callback
  automatically. The unchanged client reached character selection.
- This game run did **not** pass stability validation. It did not emit the earlier
  SmallMemAllocator `ERROR #139`, but did log a failed `mprotect` with errno 13 and
  a Lua runtime-code-generation panic, followed by `ERROR #132`,
  `EXC_BAD_ACCESS / KERN_PROTECTION_FAILURE`, and `_exit(1)`. The user confirmed
  returning to the iPhone home screen. Absence of the prior assertion in this one
  run does not prove every allocation boundary is correct.
- Replacement installation preserved all 1,877 existing client files by path, size
  and modification time, including 55 CASC archives; `Config.wtf` was byte-identical.
  No client data was removed or downloaded, and the game executable was unchanged.

A separate built-in host-only `--execution-probe=wx` run, after the game had exited,
was terminated with `CODESIGNING / Invalid Page` when calling its generated return-42
sample. `MAP_JIT` was rejected (errno 1); changing ordinary writable memory to RX
was accepted but did not make the sample executable. This probe did not use a
Developer-service-prepared arena and is not another game crash. The ordinary launcher
was restored afterward. Compatibility of dynamically generated code with the existing
prepared-arena model remains unresolved.

The required iPhone Duo and iPad Pro 13-inch (M5) simulator instances were unavailable.
Device and simulator SDK builds passed; these are not simulator execution results.
World-entry stability remains unverified. This result applies only to the installed
source/device/mode/client combination above.

## Dynamic-code follow-up: iPhone 17, 2026-11-22

Diagnostic source based on `9ac0b4b`, with `CodeRemap.c` and the opt-in
`--local-code-remap-probe` launcher entry; iOS 27.2.1, Developer service.
No new guest memory implementation was enabled.

| Host-owned test | Mac arm64 | iPhone 17 |
| --- | --- | --- |
| Shared RX view remapped at a stable target address | Native Mac mappings: return-42 and 128 rewrite/execute cycles passed under ASan/UBSan; adjacent page preserved | Mapping returned success, but no fixture value returned; the process exited with `SIGBUS` |
| Existing arena probe: write through RW alias, execute at original RX address | Covered by the platform fixture | Returned 42, then 1337 after rewriting: passed |
| Existing arena probe: change the original view to RW, write, then restore RX | Platform fixture permits device-dependent outcome | Restore RX rejected with errno 13; RWX also rejected with errno 13 |
| Ordinary anonymous code after Developer service detached | Not an iOS permission test | `MAP_JIT` rejected with errno 1; calling the ordinary mapping failed with `SIGBUS / KERN_PROTECTION_FAILURE` |

The remapping probe used only owned return-value code in two fresh pages. The original
`--jit-probe` sized an arena from the existing application's loading metadata and ran
only its owned spare-page samples, skipping all guest entry. Neither test inspected
or changed game instructions, and neither attached a debugger after fixture entry.
The two system exits belong to these diagnostics, not to new game sessions.

These results rule out the tested remapping and direct-protection routes on this
configuration. A runtime that generates code needs to cooperate with the prepared
RW-alias/RX-address model; substituting a successful return from `mprotect` would be
incorrect. A compatible Lua runtime or an application-supported interpreter option
has not been established. The Lua panic is **not fixed**, and no new game stability
pass is claimed.

The diagnostic replacement retained all 1,885 existing client files by path, size and
modification time, including 55 CASC archives, and identical `Config.wtf`. CN/zhCN,
persistent in-app sign-in, and the earlier C++ ownership fix were kept. The ordinary
launcher was restored after both probes. Required simulator execution remains
unavailable; a Mac fixture pass is not an iOS permission pass.

## Report a problem

Start with [Install WolkaraForever](docs/INSTALLATION.md) and [Use WolkaraForever](docs/USING_WOLKARAFOREVER.md). When you report a problem, follow [Send us a log](docs/SENDING_LOGS.md) and include the exact Technical details message if one was shown. Do not include credentials, signing material, pairing records, account information, or device identifiers.
