# Install WolkaraForever

> Reviewed: 2026-11-24 · Source behavior: `0a38398`

Install WolkaraForever from source on an iPad or iPhone. This guide uses the supported Developer-service route; [Build and run WolkaraForever](BUILDING.md) covers the other execution modes and the build itself.

## Requirements

- Apple-silicon Mac with current Xcode, Xcode command-line tools, XcodeGen, and Python 3. An Intel
  Mac runs the same commands but `install_prerequisites.sh --check` warns that the documented path
  and the device builds are arm64.
- Paid Apple Developer membership.
- Unlocked iPad or iPhone in Developer Mode that trusts your Mac.
- About 70 GB free for the Forever game data and its updates (the launcher also keeps a 1 GB reserve).
- Your own eligible game account and game data.

## Configure the build

1. Clone the repository and create your private configuration.

   ```sh
   git clone https://github.com/icechriszen/wolkaraforever.git
   cd wolkaraforever
   cp local.env.example local.env
   ```

2. Fill in your active paid development team and unique bundle ID in `local.env`.
   Keep `TOLKARA_MODE=developer-service`. Keep the signing team, bundle ID and Keychain
   group stable on updates so the app retains its container, credentials and enrollment.
   Xcode must show the paid team; a Personal Team alone is not this setup.
3. Check prerequisites, select the connected device, and run preflight.

   ```sh
   wolkaraforever/tools/install_prerequisites.sh --check
   wolkaraforever/tools/device_variables.sh --write
   wolkaraforever/tools/preflight.sh
   ```

## Install and start

Run:

```sh
wolkaraforever/tools/install.sh
```

The installer builds, signs, installs, and launches the app through project safety checks. It refuses to replace a running game unless you request that action. Do not use raw device-file commands to install or copy game data.

On first launch, choose Forever, a region, and a game language. Download the required data and select **Play** only after the launcher reports that it is ready.

The supplied configuration selects **Developer service**. The ordinary Forever home
uses that route and has no execution-mode picker. Alternative builds and development
launch overrides are described in [Building](BUILDING.md).

Keep the device unlocked and connected over USB for the first enrollment. The system
may ask to add the local developer-service VPN configuration. Its packet provider
routes only the local service address, excludes the default route, and adds no DNS
override or external VPN endpoint. It transports requests to the on-device developer
service that prepares memory before the game starts.

For China, choose **Game Settings Manager → Region / Locale → China / zhCN** and use
[the in-app Battle.net login](USING_WOLKARAFOREVER.md#experimental-battlenet-login).
The game and bundled add-on can use Chinese; launcher labels remain English, German
or French. See [iPhone setup](IPHONE.md) or the [Chinese guide](../README.zh-CN.md).

## Update or recover

Exit the game normally, wait for its save, then close Wolkara from the app switcher.
Run `git pull --ff-only` on the selected fork branch and run `install.sh` again with
the same private configuration. A live-session or active-write refusal is a reason
to finish exiting and retry. Do not delete the app: that removes downloaded data
and configuration. Installing the app does not update an already installed add-on;
afterward use **Install Addons (Curse & Direct) → WolkaraRoue (bundled) → Update**.

## Troubleshooting

| Problem | What to do |
| --- | --- |
| Prerequisite check fails | Install the named Mac tool, then run the check again. |
| Device is missing | Unlock it, reconnect it, confirm trust and Developer Mode, then rerun `device_variables.sh --write`. |
| Install refuses replacement | Stop the game from the app before retrying. |

Read [Compatibility](../COMPATIBILITY.md) for support limits.
