# Send us a log when something goes wrong

> Reviewed: 2026-11-24 · Source behavior: `0a38398`

A log is a text file that records what the app was doing. When something fails, the log
usually says why, and it saves a lot of guessing. You do not need a Mac, a computer cable,
or any technical knowledge to send one — it is a few taps on the iPad.

## The short version

1. Open WolkaraForever and stay on the home screen (the one with **Play**).
2. Tap **Settings** at the top right, then **Diagnostics and logs**.
   (On the app-library screen, the stethoscope icon opens the same page.)
3. Scroll to **Logs and reports**. The **newest file is at the top** — usually
   `wolkaraforever.log`, or `native-guest.log` if you have just played.
4. Tap it, then tap the **share icon** at the top right (a square with an arrow), and
   choose **Mail**, **Messages**, **AirDrop**, or **Save to Files**.
5. Send it with a couple of sentences about what went wrong — see
   [what to write](#what-to-write-with-the-log).

That is the whole procedure. The page you are reading has more detail for the times when
it does not go that smoothly.

## Which file to send

Send the **newest** file unless the situation below matches better.

| File | What it holds | Send it when |
| --- | --- | --- |
| `wolkaraforever.log` | What the launcher did: start-up, the game check and download, add-ons, settings, the interface | The launcher is slow, a row does nothing, a setting does not stick, a download or repair misbehaves |
| `native-guest.log` | The game and the compatibility layer **during a run** — including anything the game itself printed | The game crashed, would not start, showed a black or frozen screen, had no sound, or the controls or keyboard did wrong |
| `host-diagnostics.txt`, `*-probe.log`, `*-probe.txt` | The reports produced by the checks on the Diagnostics page | Only when you were asked to run a specific check — mention which one |

If you played and then sent `wolkaraforever.log` alone, the game part is missing. When in
doubt, send both: two small files are better than one that has to be asked for twice.

## If the app will not open at all

You can still get the files out, because the app keeps them in a folder iPadOS lets you
browse:

1. Open the **Files** app.
2. Tap **On My iPad**, then the folder named after the app (**WolkaraForever** unless you
   renamed your build).
3. Tap and hold the file you want, then **Share**.

With a Mac and a cable you can instead open **Finder**, select the iPad, open the **Files**
tab, find the app, and drag the files out. No cable and no computer is needed for the Files
app route.

## If you are on a Mac and have the project

These read the app's own logs from the iPad without disturbing a running game — they copy a
file, they do not attach to the app:

```sh
wolkaraforever/tools/device_log.sh 200          # the last 200 lines of the run log
wolkaraforever/tools/device_log.sh 120 error    # only lines matching "error"
wolkaraforever/tools/pilot.sh log 80            # the launcher's own log
```

`device_log.sh` reads `native-guest.log`; `pilot.sh log` reads `wolkaraforever.log`. Both read
`DEVICE` and `TOLKARA_BUNDLE_ID` from your `local.env`. `device_log.sh` falls back to
`local.tolkara.app` when the bundle ID is not set there; `pilot.sh` stops and asks for one.

`pilot.sh state` and `view` include both the client's `_Error_` assertions and
`_Crash_` fatal exceptions when finding the newest client report. These are separate
from iOS's own `.ips` reports.

`pilot.sh crash` reads the newest ordinary app crash report. To inspect a specific
app system report from the device's report listing, pass its exact filename, for example
`pilot.sh crash Tolkara.cpu_resource-YYYY-MM-DD-HHMMSS.ips`. Only listed Tolkara or
TolkaraDiagnostics reports are accepted. Resource reports do not count as crashes;
match their timestamps and recorded action to the failed attempt before drawing a conclusion.
The selected report is copied into the pilot session's local `crash/` directory.

## Chat sends nothing

Start with the app build and the installed **WolkaraRoue (bundled)** version; an app
update does not automatically update an existing add-on. The Chinese-input runtime
fix was validated at `b535ee4` with add-on `1.0.5-cn.7` in **Classic direct** mode.

1. Note the keyboard/delivery mode and whether the attempted text was Chinese,
   ASCII or mixed. Do not include the message body.
2. `/mobile error` reports the add-on's last Lua exception. “No errors” does not
   prove that text reached the input box or that a message was sent.
3. `/mobile chatdiag` prints local counters for opening the input, non-empty text,
   Return, modern/legacy send API calls, self echo and display processing.
4. After one reproduction, exit the game normally to save the trace and do not
   reopen it before collection. The next UI load starts a fresh trace. A crash may
   leave no saved trace for that attempt.

The cn.7 trace keeps at most 32 events plus counters: lengths, fixed state names,
numeric error IDs and hook availability. It records no message body, character
name, recipient or player identifier. A send API count is an attempt; self echo
and visible display are separate evidence. Check hook availability and observer
errors before interpreting a zero. Running `/mobile chatdiag` is itself an input
command and may increase input counters.

The native log's `keyboard: a line went to the chat` means events were queued,
not that delivery succeeded. `text commit: units=… modern=… legacy=…` confirms the
Unicode bridge was invoked; it also does not replace the self-echo check. Avoid
raw key tracing when collecting login/chat evidence, and do not post complete
account SavedVariables files. Provide the summary or the requested redacted
metadata through [this fork's issues](https://github.com/icechriszen/wolkaraforever/issues).

## Opt-in host lifetime diagnostics

For a Developer service freeze or allocator failure, run the installer with
`WOLKARA_HOST_DIAGNOSTICS=1` to produce a diagnostic build (also works with
`--build-only`), or launch with `--host-lifetime-diagnostics`.
Normal builds leave this disabled. It records process memory totals and a main-queue
heartbeat every five seconds, for at most ten minutes, in
`Documents/host-lifetime-diagnostics.log`. Fixed lifecycle events and memory warnings
are also recorded. A new process replaces this file when its native session starts;
collect it before reproducing again.

The matching `[host-tls]` lines in `native-guest.log` record only allocation/release
metadata for thread-local storage owned by Wolkara's runtime, with a 4,096-event limit.
They do not inspect game memory, install signal handlers, attach a debugger, replace
allocator behavior, or alter game settings. A missing release-end can narrow a failure
but does not by itself prove its cause. Correlate it with the actual client/system report.

Retrieve the separate counter log with the existing read-only tool:

```sh
DEVICE_LOG_FILE=host-lifetime-diagnostics.log wolkaraforever/tools/device_log.sh 200
```

The owning synthetic Mac tests run with ASan/UBSan through
`wolkaraforever/tools/test_host_lifetime_diagnostics.sh`; they do not establish that a
physical game crash has been fixed.

## What to write with the log

Five short lines are plenty:

1. **What you expected** — "I expected the game to start".
2. **What happened instead** — "It showed a black screen", "It closed after the loading
   bar", "The keyboard typed nothing".
3. **What you did just before** — "Chose German, then pressed Play", "Connected a
   controller", "Opened the add-on manager".
4. **Today's date and the time it happened** — to the nearest few minutes, so the right part
   of the log can be found.
5. **Your setup** — the mode you chose (Developer service, External JIT, or Local signing),
   which game edition, the iPad model and iPadOS version (**Settings → General → About** on
   the iPad), and the app version, which is the first line of `wolkaraforever.log` (it reads
   `--- <app name> <version> (<build>) pid <n> launched ---`).

Screenshots help too, especially for anything visual. Take them before you restart the app
if you can.

## What is in a log, and what is not

The launcher avoids recording passwords and login tickets. Native run logs also
contain output from the game itself and may contain local paths or other context;
review and redact them before sharing. Do not assume that a complete run log is
anonymous. The bounded chat trace above deliberately excludes message content.

`wolkaraforever.log` is one line per event, shaped like `10:44:03.912 [ui] …`. The word in
brackets is the topic, and it is the quickest way to find the part of a log a report is about:

| Topic | What it records |
| --- | --- |
| `host` | The app itself: launch, arguments, which screens opened, a failed start |
| `ui` | What you chose and what the page did: interface mode, layouts, Battery Saver, device and render profiles, backups, the controller touchpad pointer |
| `wow` | The game check, update progress, verification counts, install state |
| `battle-login` | Experimental sign-in and password-setting actions; no password or ticket value |
| `voice` | Dictation: learning the button, starting and stopping capture, recognition |
| `audio` | The audio session and the battery-saving sound path |
| `input`, `controller-input` | Input routing and controller commands |
| `language` | The app's language and the game's language |
| `addons`, `addon-hub` | The add-on store, and the hub's own structured events |
| `network` | Arming and disarming the anonymous connection-health counters; the counters themselves are written as `[network-health]` lines in the native log |
| `jit` | External JIT and the enabler's detach |
| `enrollment` | The developer-service enrollment |
| `config` | Reading and writing the app's own settings |
| `selftest` | The app's own device self-tests |

The log rotates at one megabyte: when `wolkaraforever.log` fills, it becomes
`wolkaraforever.log.1` and a new file starts. Only the current file is listed under **Logs and
reports**; if support asks for the previous one, get it from the app's folder in the Files app.

You are welcome to open a log and read it before sending — it is plain text. If you would
rather not share a line that mentions a folder path or a device name, say so and we will tell
you which lines matter; you can blank the rest.

Never send:

- passwords, account details, complete browser return URLs or `ST`/launch tickets;
- signing certificates, provisioning profiles, or anything from your keychain;
- pairing records or anything from `authorized_keys`-style files.

Do not delete or reinstall the app as a first step. The log you would need is deleted with
it, and most problems are configuration, which reinstalling does not change.

## When the instructions above do not fit

| What you see | What to do |
| --- | --- |
| **Logs and reports** says "No logs yet" | Nothing has been logged in this install. Open the game once (even if it fails), come back, and the list will be there |
| The list is long and you cannot tell which file is which | The top one is the newest. Its name is in the row; tap it and the first lines say when the app started |
| The share sheet has no Mail | Choose **Save to Files**, then attach the saved file to an e-mail or a message |
| The file is very large | The viewer shows only the last part; that is normal. Share the **file** — the full log is what is wanted |
| You cannot find a log for the game | `native-guest.log` appears after the game has actually run at least once. Start the game, let it fail, then send it |
| Someone asked you for "the exact Technical details message" | In the app's **Settings** sheet, choose **Technical details** when it is offered (it appears after a failure) and copy the text it shows. It is one line, and it goes with the log |
