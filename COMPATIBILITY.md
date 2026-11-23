# Compatibility and support boundary

> Verified: 2026-11-13 · Source: `3c33543`

WolkaraForever is a source-built project for an iPad or iPhone that you own and configure with your own Apple Developer account. The supported integrated route requires Developer Mode, current Xcode tooling, and an execution path that can prepare executable memory.

## Wheel capacity and chat entry acceptance: iPhone 17, 2026-11-23

Source `7ccce97` was built, strictly signature-verified and installed with the
original project tools on iPhone 17, iOS 27.2.1, Developer service, CN Forever
1.60.1.71037. The ordinary launcher returned to **Ready to play**. At app
replacement, all 2,069 client files and 55 CASC archives retained identical
metadata; the six selected configuration/add-on files retained identical SHA-256
hashes. The user subsequently updated the in-game add-on through Add-On Manager;
readback with the original project tools confirmed `1.0.5-cn.4`. Saved settings
readback retained `zhCN`, Standard and five slots per side.

The user's saved Standard layout had five slots per side even though only three
were visible. The updated production-Lua fixture checks five visible slots at the
phone's Standard UI scale, plus automatic visibility of newly added slots through
twelve on both sides. The same test fails against the preceding geometry. Lua,
package verification (including nine rejected malformed packages), layer and
documentation checks passed. The chat fixture also covers legacy/namespaced input
APIs and Standard/Duo input hints. After the update and world entry, the user
reported that the requested acceptance checks were normal, covering wheel slot
addition and chat sending. This is user-operated physical acceptance, not Device
Hub interaction. The last selected chat delivery mode was Classic direct; a
separate Review-mode retest, all twelve slots on the physical device, and extended
stability were not independently measured. The precise client API availability
was not captured, so the compatibility fallback is not asserted to be the sole
cause of the earlier chat failure. No simulator execution is claimed.

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

## CN world-entry validation: iPhone 17, 2026-11-23

Installed source `1e783f7`, iOS 27.2.1, Developer service, unchanged CN Forever
1.60.1.71037 / zhCN, with host diagnostics enabled. This result supersedes the
failed character-screen/world-entry status above for this tested combination:

- `5cf5bb9` corrects ordinary anonymous `mmap` address hints inside the reserved
  image: a non-fixed, non-MAP_JIT hint no longer clears or reprotects occupied
  image pages. The Mac ASan/UBSan regression verifies relocation and preservation
  of existing and adjacent bytes. Explicit fixed-map and MAP_JIT image-rewrite
  handling remains unchanged.
- After that correction, the next reproduced failure was a `CFRetain(NULL)` trap,
  followed by the client's reporting path and a system watchdog termination.
  The adapter had returned nil when a valid local event monitor was registered
  without a development flag. `1e783f7` registers it with the existing dispatcher
  on ordinary launches and returns the real removable token. It does not suppress
  CoreFoundation's NULL trap. The ownership regression covers CF retention,
  callback removal, token destruction, filtering, replacement and consumption.
- The user reported a stable character/graphics screen with a working keyboard,
  then successful world entry with normal rendering and keyboard interaction.
  Fresh project-tool captures confirmed a registered local-monitor token, no
  `CFRetain(NULL)`, Lua PANIC or reported `mprotect` failure, and no additional
  client error file or system crash report. The game was left running.
- Replacement installation preserved all 1,909 existing client files by path,
  size and modification time, including 55 CASC archives. CN/zhCN, persistent
  in-app web sign-in, and the C++ allocation boundary fix were retained. No game
  executable or downloaded archive was edited.

This is one successful game session, not a repeated cold-launch or long-duration
stability result. A carried library's MAP_JIT request still returned errno 1;
continued world entry shows that this observed denial alone did not terminate
this session. These fixes do not grant arbitrary new anonymous pages execution
permission, establish that Lua JIT compiled a trace, or make the earlier failed
host-only code-remapping probes pass. Required simulator execution is still not
claimed; the matrix instances were unavailable. Mac sanitizer checks, layer/docs
checks, and the signed iPhone build passed.

## Chinese touch add-on validation: iPhone 17, 2026-11-23

Installed source `d17deea`, iOS 27.2.1, Developer service, CN Forever
1.60.1.71037 / zhCN. The user updated the bundled WolkaraRoue package from an
unmanaged 0.6.1 copy to 1.0.5-cn.1, entered the game, and confirmed that its menus
were Chinese. Readback through the project tools verified that the installed TOC
and Language.lua were byte-identical to the reviewed source. Game-owned menu
labels prefer the client's zhCN strings; spell and item names use game APIs.

The visible **Install Addons (Curse & Direct)** entry now exposes the bundled
package. Its explicit Update action can adopt the old unmanaged folder through
the existing transaction journal without inventing a provider link. Production
archive/store tests passed for exact-folder restrictions, invalid-archive refusal,
injected commit-failure rollback, unchanged SavedVariables and unrelated add-ons,
and subsequent ordinary updates. General automatic-update ownership guards remain.

Before the add-on update and game launch, replacement app installation preserved
all 1,975 client files by path, size and modification time, including 55 CASC
archives and 58 WTF files. CN web sign-in and the earlier runtime fixes were kept.
The signed device build and layer/docs checks passed. The interface result is
user-operated physical-device evidence; the required iPhone Duo and iPad Pro
13-inch (M5) simulators were unavailable, so no simulator UI pass is claimed.

## Cold-launch and touch follow-up: iPhone 17, 2026-11-23

Installed source `d17deea`, iOS 27.2.1, Developer service, unchanged CN Forever
1.60.1.71037 / zhCN, WolkaraRoue 1.0.5-cn.1. A later character-selection session
froze before any touch-fix installation. The client reported a protection fault;
the system report retained an instruction-abort permission fault on a worker
thread, with PC equal to the fault address inside the recorded 64 KiB anonymous
mapping. Its RW-to-RX `mprotect` had returned success. The final process termination
was a scene-update watchdog, not the initial fault. Dynamic-code execution remains
unresolved; the earlier successful world-entry session is not a cold-launch guarantee.

The user also reported that tapping button centres missed while nearby taps worked.
Candidate `bc25ca8` fixes a separate, confirmed mode-resolution mismatch: the toolbar
accepted Automatic/iOS Duo while the host recognised only explicit iOS. It shares
the existing resolver and direct gestures, with no resolution, add-on, saved-layout,
or fixed-offset changes. The signed iPhone build, layer/docs checks, and simulator
SDK compilation of the host tap fixture passed. Both required simulator instances
were absent; the fixture did not execute. The project installer refused replacement
while a game session was live. At that stage, no physical click-accuracy pass was claimed.

## Controller startup installation: iPhone 17, 2026-11-23

Candidate source `eb71444` combines the `bc25ca8` touch-mode correction with a
launch-time controller policy. Immediately before Play enters the Forever guest,
an attached physical gamepad suppresses WolkaraRoue auto-loading and the native
keyboard/controls toolbar. Without a gamepad, both are enabled. The add-on switch
changes only its TOC loading field and its own entries in existing character
AddOns.txt files; the toolbar uses a process-only defaults override. It neither
resets SavedVariables nor replaces the Chinese package or Gamepad UI bindings.

The production Foundation file-operation suite passed controller/unplugged/new
character cases, unchanged Chinese bytes and saved layouts, idempotence, oversized
file and symlink refusal, and rollback after an actual failed atomic write. It also
verified that the toolbar override leaves persistent preferences unchanged. The
37 UI archive checks, Lua/Chinese add-on tests, layer/docs checks, private Developer
service Release build and strict signature verification passed. Required iPhone Duo
and iPad Pro 13-inch (M5) simulators were absent; no simulator execution is claimed.

After the user exited the game, the original project installer replaced the app
under its existing bundle identifier with source `4507666` (the runtime changes
are `eb71444`). Device: iPhone 17, iOS 27.2.1, Developer service, unchanged CN
Forever 1.60.1.71037 / zhCN. The ordinary launcher returned to **Ready to play**,
and its own check finished with `state=3 error=none`, without starting the game.
The install bridge could not repeat the USB enrollment handshake; the original
installer retained the pre-existing enrollment, rather than replacing its identity.
The subsequent user-operated Play launch reached CN character selection with the
existing enrollment.

All 2,016 existing client files retained their paths, sizes and modification times,
including 55 CASC archives. Six selected files also retained their SHA-256 digests:
the zhCN add-on TOC and Language.lua, Config.wtf, the character add-on enable list,
and the WolkaraRoue SavedVariables file and its backup. No client data was removed
or downloaded. The new launch policy has not yet run in this preservation check.

The state tool conservatively classified the new launcher as live from an old
native-guest log. That log was byte-identical before and after installation; the
current screenshot and launcher log instead showed the normal home page and a
non-launching client check. The original install/stop guards were not changed or
overridden.

In the attached GameSir USB controller test, the launcher logged physical
controller detection and both automatic loading and toolbar disabled. A read-only
capture showed CN character selection without the native bottom toolbar. The user
confirmed that both touch UIs were hidden and the sticks and buttons worked. The
client error count (27) and system crash count (12) did not increase in that check.
On the next launch after unplugging the controller, the user confirmed both touch
UIs returned, the Chinese language and original layout were retained, and taps at
wheel-icon centres triggered normally. Readback logged no physical controller and
both features on; the TOC was byte-identical to the reviewed Chinese source again,
with the temporary LoadOnDemand field removed. Together these user-operated runs pass
the requested startup switching and reported touch-offset reproduction on this
installed build. They do not measure every touch position or prolonged stability.
This is user-operated physical evidence; Device Hub was unavailable.
This change does not alter or claim to solve the dynamic-code fault recorded above.

## Standard layout and chat validation: iPhone 17, 2026-11-23

Source `a7a1f22`, with bundled WolkaraRoue `1.0.5-cn.2`, was installed using the
original project installer after the user exited the game. Device: iPhone 17,
iOS 27.2.1, Developer service, CN Forever 1.60.1.71037 / zhCN. The ordinary
launcher reached **Ready to play**. All 2,030 existing client files, including
55 CASC archives, retained their paths, sizes and modification times across the
app replacement; six selected configuration/add-on files retained their SHA-256
digests. The later bundled add-on update intentionally replaces add-on code.

ChatTab previously hid the chat panel's X button unconditionally and replaced its
Show method. The fix leaves the method intact and hides the X only while the Duo
chat pill is active. The original code fails the new Standard close-button
regression; the fixed Standard/Duo visibility and close-action fixture, Lua/Chinese
suite, package verifier, layer/docs checks, Release build and strict signature
check passed. Required matrix simulators were absent; no simulator run is claimed.

Before installation, the user confirmed default UI restoration, Chinese text and
native joystick movement. A read-only settings copy showed Standard / zhCN with
`shortcuts.enabled=false`, accounting for the missing top bar; it does not establish
which action disabled that setting. After the user updated the bundled add-on and
enabled **Spell wheels → Shortcuts**, they confirmed that the top buttons returned
and the chat X closed the panel. A subsequent read-only device TOC copy confirmed
`1.0.5-cn.2`. These are user-operated physical results; Device Hub was unavailable.
The current upstream add-on remains installed, with its Standard layout selected.
No game binary, runtime or controller startup policy changed in this UI fix, and
the previously recorded dynamic-code failure remains outside this validation.

## Native control geometry installation: iPhone 17, 2026-11-23

Source `9af9e57` was installed with the original project tools after they verified
the user had dismissed the background game process. Device: iPhone 17, iOS 27.2.1,
Developer service, CN Forever 1.60.1.71037 / zhCN. The ordinary launcher returned
to **Ready to play**. All 2,037 existing client files and 55 CASC archives retained
their paths, sizes and modification times. Six selected configuration/add-on
files retained their SHA-256 digests. The only metadata differences were data
protection extended attributes added to 73 files by the iOS container manager;
none of the archives' metadata changed.

The installed build exports fixed compact native control geometry before Play into an
owned add-on data file. Standard spell wheels use those centres and keep their
hit boxes clear of the sticks. Add-on menus/settings, bags and game windows fit
between or above the native hit regions and keyboard toolbar. Saved native
positions, skill assignments and Chinese preferences are retained. The bundled
`1.0.5-cn.3` package also uses the short Chinese menu labels 法术书 and 地图; the
host's compact jump control retains its binding and hit area without visible text.

The actual phone viewport regression covers both spell wheels at several UI and
button scales, plus menu/settings, bag and map exclusion rectangles. The previous
Turn and Windows implementations fail those regressions. The Lua/Chinese suite,
native geometry/export and configuration-preservation tests, 37 archive checks,
package verifier, layer/docs gates, Release build and strict signature check
passed. These source fixtures do not establish live interaction success; no
simulator UI execution is claimed.

After updating the bundled add-on, the user confirmed that both the spell-wheel
overlap and the menu/bag overlap disappeared, and that tapping, movement and
jumping worked normally. Read-only device copies confirmed add-on version
`1.0.5-cn.3` and all 15 bounded native geometry fields. A subsequent screenshot
showed the spell buttons surrounding the actual sticks, the short Chinese top-bar
labels 法术书 and 地图, and the jump control without visible text. This passes the
reported reproduction on the installed iPhone build. Interaction evidence is
user-operated; Device Hub was unavailable, and the screenshot corroborates
appearance rather than proving input. The running game was not stopped. This
validation does not claim to resolve the earlier dynamic-code fault or establish
prolonged stability.

## Wheel gesture follow-up: iPhone 17, 2026-11-23

On installed source `7ccce97`, WolkaraRoue `1.0.5-cn.4`, the user subsequently
reported that the left empty-slot plus did not open its picker. A read-only
capture showed the movable chat strip over that slot. After moving the strip
clear with `/mobile edit`, the user confirmed that the picker opened. This is
user-operated evidence on iPhone 17, iOS 27.2.1, Developer service, CN Forever
1.60.1.71037 / zhCN; Device Hub was unavailable.

The user then reported that dragging one wheel slightly moved the other, and
that native stick operation also moved wheels. The production-Lua fixture
reproduced a stale preview: when a moving spell button misses OnMouseUp, its
wheel follows the shared cursor indefinitely. Source `7ccce97` fails the new
release regression. The `1.0.5-cn.5` candidate gives the out-of-combat preview one
owner and checks held-left-button state, drag-stop, hide, layout and combat
transitions. It keeps the existing secure swipe snippets, skill assignments,
Chinese strings, native controls and runtime unchanged. The Lua/Chinese suite
passes, including alternating wheels, a late old-button release, pointer motion
after release, fresh taps and protected combat cleanup. These fixtures establish
the source failure and correction, not the cause or resolution of every physical
gesture. Source `3d56adc` built successfully in Release with Developer service;
the strict signature check and bundled-source hash comparison passed. Package
verification, layer checks and documentation/catalog checks also passed. The
layer gate reported its existing missing-upstream-merge-base limitation. Both
required matrix simulators were absent, so no simulator interaction is claimed.
After the user exited normally, the original tools verified no live game and
installed source `ff5acbf` (runtime/add-on change `3d56adc`). The launcher returned
to **Ready to play** and the installed-build signature and bundled-source hash
checks passed. All 2,075 existing client files remained present, including 55
CASC archives with unchanged metadata. The user's add-on update overlapped the
post-install readback: Turn.lua, the generated HostTouchLayout.lua and the add-on
manager record changed as expected, while 84 files gained/changed protection
extended attributes. The first selected-file copy failed; the later read-only
copies succeeded, so no all-files byte-for-byte preservation claim is made.

Readback confirmed installed WolkaraRoue `1.0.5-cn.5`. Language.lua, AddOns.txt,
and WolkaraRoue's SavedVariables and backup matched their pre-install SHA-256
digests. The TOC carries the new version; Config.wtf retained zhCN and changed
only `gameTip` and `perksActivitiesPendingCompletion`. The user reported all
operations normal after the update, passing this reported wheel/stick coupling
reproduction. This is user-operated iPhone evidence, not Device Hub automation
or a prolonged stability test. No game process was forcibly stopped, no client
archives were replaced, and the CN sign-in adaptations were retained.

## Chat input initialization investigation: iPhone 17, 2026-11-23

After accepting `1.0.5-cn.5` wheel behavior, the user again reported no chat
message after pressing Send. The current native log confirmed stored
`classicDirect`, the system draft keyboard and one ordinary-message dispatch.
That log records an input request, not server receipt. The user could not yet
repeat the explicit `/s ` comparison; account/channel restrictions and actual
Unicode delivery remain unmeasured on this run.

The source path sends F12, the committed line and Return together. The
[game UI opener](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua)
activates the edit box immediately but defers the supplied prefix, and the
[edit box update](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua)
writes and parses it on a later frame. This leaves a channel-selection and text
overwrite race. The default upstream Chat.lua still uses that prefix-based
opener; the earlier local namespace compatibility fix did not address timing.

The `1.0.5-cn.6` candidate activates through the game's API, resolves the actual
active edit box, clears pending initialization, then sets/parses the selected
prefix synchronously with send=0. It never calls a chat-send API or retries a
message. The existing keyboard Return is still the submit action. The fixture
models the deferred initialization and immediate text burst; source `63fff04`
fails the new test. The candidate passes modern/legacy API fallbacks, five
destinations, a previous pending prefix, preservation of subsequent Chinese and
ASCII text across the next frame, and a focus failure. The full Lua/Chinese and
wheel suites pass. This establishes a source defect and candidate correction;
it does not yet establish that this is the sole cause of the phone symptom.

## Report a problem

Start with [Install WolkaraForever](docs/INSTALLATION.md) and [Use WolkaraForever](docs/USING_WOLKARAFOREVER.md). When you report a problem, follow [Send us a log](docs/SENDING_LOGS.md) and include the exact Technical details message if one was shown. Do not include credentials, signing material, pairing records, account information, or device identifiers.
