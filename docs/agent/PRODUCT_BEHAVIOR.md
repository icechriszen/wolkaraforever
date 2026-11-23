# Product behavior

> Verified: 2026-11-23 · Source: `0a38398` · Proof: source review and dated compatibility records

WolkaraForever lets a user choose a Forever region and game language; download, resume, verify, repair, and update game data; then start the unchanged executable through an available execution mode. The launcher also supports app localization, interface-mode selection, opt-in experimental Battle.net browser login, add-ons, UI recovery, keyboard/controller/touch input, dictation, battery-saving sound, and diagnostics.

| Behavior | Human guide |
| --- | --- |
| Install, signing, first launch | [Installation](../INSTALLATION.md) |
| Build assembly, execution modes, run commands, packaging | [Build and run WolkaraForever](../BUILDING.md) |
| Game lifecycle, languages, experimental browser login, add-ons, recovery, controls, voice, battery-saving sound | [Using WolkaraForever](../USING_WOLKARAFOREVER.md) |
| Phone-specific interface and constraints | [iPhone](../IPHONE.md) |
| Supported boundary and issue reports | [Compatibility](../../COMPATIBILITY.md) |

The launcher records only managed add-ons for removal, stages updates and restores before replacement, and keeps diagnostics redacted. An API key is device-local and optional; browser or Files acquisition remains available where appropriate.

The ordinary Forever home uses the configured execution route and has no mode
chooser. The supplied `local.env.example` selects Developer service; development
launches can override it explicitly. The internal library chooser is not a public
home-screen setup instruction.

This fork adds CN/zhCN, persistent in-app website login, Chinese Standard touch UI,
startup controller-based add-on/toolbar selection and ordered Unicode input.
The launcher itself remains en/de/fr. Keep app mode, add-on layout and game locale
separate in help text; link the Chinese guide for the tested phone workflow.

## Refresh when

Refresh after any user-visible launcher, lifecycle, localization, input, add-on, recovery, diagnostics, or execution-mode change.
