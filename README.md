<p align="center"><img src="docs/assets/wolkaraforever-logo.png" width="360" alt="WolkaraForever"></p>

# WolkaraForever — CN / iPhone fork

> Reviewed: 2026-11-24 · Validated runtime: `b535ee4` · Bundled add-on: `1.0.5-cn.7`

[简体中文与安装说明](README.zh-CN.md) · [User guide](docs/README.md) · [Validation record](COMPATIBILITY.md)

Run World of Warcraft Forever locally on an iPad or iPhone with a source-built WolkaraForever installation. The app downloads and maintains your game data, then starts the unchanged client through Tolkara. It is not a streaming service and does not include game files.

This is [icechriszen's fork](https://github.com/icechriszen/wolkaraforever), based on
[jklock/wolkaraforever](https://github.com/jklock/wolkaraforever) as its primary upstream.
The default `main` branch integrates the locally validated CN/iPhone changes and
this documentation. No new release tag or prebuilt IPA is implied; the recorded
iPhone results and remaining validation limits are listed below.

## Changes in this fork

| Area | Changes |
| --- | --- |
| China client | CN region, zhCN game locale, official regional download metadata and CDN support |
| Battle.net login | In-app China web login, remembered website session and validated Safari return fallback |
| Runtime | Scoped C++ allocator ownership, anonymous-map hint handling and local event-monitor registration fixes |
| Touch UI | Chinese WolkaraRoue, Standard layout fixes, wheel/stick spacing, wheel gesture ownership and working empty slots |
| Controller | At Play, an attached controller suppresses WolkaraRoue and the bottom touch toolbar; the next controller-free launch restores them |
| Chat | Ordered Unicode text commits, synchronous channel initialization and bounded content-free diagnostics |

User-operated iPhone 17 / iOS 27.2.1 / Developer service tests with CN Forever
1.60.1.71037 confirmed world entry, touch/controller switching and Chinese chat
delivery. Required simulator runs and extended stability remain unverified.
TW/zhTW is selectable but has no completed TW client comparison. See
[Compatibility](COMPATIBILITY.md) for the exact scope and historical results.

## Before you begin

You need an Apple-silicon Mac, current Xcode and command-line tools, XcodeGen, Python 3, a paid Apple Developer membership, and an unlocked device in Developer Mode. Reserve about 70 GB for Forever. An Intel Mac runs the same commands and is warned about, not refused, but the documented path and the device builds are arm64.

## Install from source

```sh
git clone https://github.com/icechriszen/wolkaraforever.git
cd wolkaraforever
cp local.env.example local.env
# Fill in your own team and unique bundle ID before continuing.
wolkaraforever/tools/install_prerequisites.sh --check
wolkaraforever/tools/device_variables.sh --write
wolkaraforever/tools/preflight.sh
wolkaraforever/tools/install.sh
```

Read [Install WolkaraForever](docs/INSTALLATION.md) before you begin, and
[Build and run WolkaraForever](docs/BUILDING.md) for the execution modes, the simulator runs, and
the unsigned External JIT package. If you would rather sideload a package than build the app,
[Install the unsigned External JIT app](docs/SIDELOADING.md) is that route.

## What you can do

- Download, resume, repair, update, and start a selected Forever client.
- Choose game and app languages independently.
- Choose the launcher interface and the add-on's Standard or Duo layout separately.
- Manage supported add-ons and recover your interface safely.
- Use touch, keyboard, controller, and optional dictation input.
- Cap the frame rate and dim an idle session with Battery Saver, and keep the game's sound without
  loading iOS's audio device layer into it.
- Keep one game password on the device, behind Face ID, for the opt-in experimental Battle.net
  login.

Read [Use WolkaraForever](docs/USING_WOLKARAFOREVER.md) and [iPhone use](docs/IPHONE.md) for procedures.
Update **WolkaraRoue (bundled)** to `1.0.5-cn.7` through **Install Addons (Curse & Direct)**
after exiting the game. An app update does not replace an already installed add-on.
The launcher remains English, German or French; game and add-on languages are separate.
When something breaks, [Send us a log](docs/SENDING_LOGS.md) — it takes a few taps on the
iPad and needs no computer.
Report fork-specific problems in [this fork's issues](https://github.com/icechriszen/wolkaraforever/issues).

## Safety and support

No mode patches, re-signs, or redistributes game code. WolkaraForever does not automate gameplay, bypass integrity checks, or inspect a running game beyond loading and verification. Read [Compatibility](COMPATIBILITY.md) for support limits and [Security](SECURITY.md) to report a vulnerability.

## Thank you

Thank you to everyone who has opened a pull request, reported a problem, reviewed a change, or
contributed to Wolkara, Tolkara, and WolkaraForever, including jklock and
[pookee](https://github.com/pookee/wolkaraforever). Attribution and licenses are maintained
in [Contributors](CONTRIBUTORS.md), [Notices](NOTICE.md) and the source manifests.
