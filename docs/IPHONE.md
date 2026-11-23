# Use WolkaraForever on iPhone

> Reviewed: 2026-11-23 · Source behavior: `0a38398`

[简体中文指南](../README.zh-CN.md) · [Installation](INSTALLATION.md) · [Measured compatibility](../COMPATIBILITY.md#current-fork-status)

The validated setup is iPhone 17 / iOS 27.2.1 / Developer service with CN Forever
1.60.1.71037. Other devices and long sessions need their own checks.

## Keep the two interface settings separate

**Launcher Manager** selects the app's interface arrangement and input mode.
WolkaraRoue's in-game **Mobile UI → General → Layout** selects **Standard** or **Duo**.
Use **Standard** for the default wheel interface described here; choosing a phone
interface in the launcher does not require the add-on's Duo layout.

The spell wheels do not move the character. Movement and camera sticks belong to
the native overlay. If they are absent without a physical controller, expand the
bottom toolbar and tap its gamepad button. In Standard, the fixed compact sticks
share their geometry with the add-on at Play, so wheels and windows leave room for
them. Restart the game after moving native controls to refresh that geometry.
Floating-stick and Duo layouts retain their own arrangements.

## Physical controller at startup

Connect the USB/Bluetooth controller before Play. With one attached, this session
suppresses WolkaraRoue's automatic loading and the native bottom toolbar. Exit
normally, disconnect the controller and start again to restore both. Plugging or
unplugging mid-session takes effect on the next launch. Saved Chinese, skills,
wheel positions and native control preferences are retained.

If the controller is recognized but cannot move the character, check **UI Manager
→ Gamepad UI** in the launcher. That game setting and controller bindings are
independent of the touch UI startup decision. USB GameSir-X5 Lite was exercised;
this is not a compatibility guarantee for every controller.

## Chinese UI, shortcuts and defaults

Update **WolkaraRoue (bundled)** to `1.0.5-cn.7` through **Install Addons (Curse & Direct)**
after exiting the game. The app and add-on updates are separate. With a zhCN game
locale, **Follow game** selects Chinese; an explicit supported add-on language is
retained. The launcher itself remains English, German or French.

| Task | Control |
| --- | --- |
| Restore top quick buttons | `/mobile` → Spell wheels / 技能轮盘 → Shortcuts / 快捷按钮 → On / 开启 |
| Move an overlapping chat strip | `/mobile edit`, move it clear of the wheel, then Done |
| Restore only native controls | Bottom toolbar gear → Reset to defaults → Done |
| Restore only add-on positions | Add-on Reset positions |
| Reset add-on settings | `/mobile reset`, then `/reload` if needed; ordinary wheel/free-button spells remain, other preferences reset |

A reset is not required for an update. On zhCN the reset language follows the game
and remains Chinese. **UI Manager → Reset to Default Wow UI Configuration** changes
game graphics/display settings, not the touch add-on's preferences. Use the game's
official graphics options for resolution; touch fixes do not force a custom resolution.

## Chinese login and chat

Select CN/zhCN and complete the official login in the app's browser. Its own website
session can persist; Safari cookies are separate. If Safari fallback ends at an
unopenable localhost address, paste that final address only into the app's masked
field and press Continue. See [browser login](USING_WOLKARAFOREVER.md#experimental-battlenet-login).

Standard chat uses the bottom keyboard button; the inline **Tap to type** entry
belongs to Duo. **Classic direct** is the physically validated send mode. Chinese
text delivery was corrected in the app runtime, so updating only the Lua package
cannot supply that fix. [Chat diagnostics](SENDING_LOGS.md#chat-sends-nothing) explain
how to distinguish input, a send attempt and a received echo without sharing text.

## Plan storage and updates

Reserve about 70 GB for the game and updates, and use a reliable network for the
initial download. Resume or repair an interrupted download without uninstalling.
Keep the signing team, bundle ID and Keychain group stable on app updates. A
second regional client needs a separate application container; changing region
inside the existing CN app can update its current game folder.

## Login is refused (`BLZ51900003`)

The game validates Battle.net certificates using macOS public trust roots carried
by this project's builds. Check the `[security] native-trusted public roots` marker
with the project's log tool when investigating a build made through another route.
The same error can also accompany unusable region/language settings; it is not a
unique diagnosis. Launcher-created CN installations set their portal/locale, while
an imported installation retains its own configuration.

## Troubleshoot safely

Keep the application installed. Use **Settings → Diagnostics and logs** and the
[log guide](SENDING_LOGS.md), including the source/add-on versions, device, mode,
reproduction steps and approximate time. Report fork-specific issues in
[this repository](https://github.com/icechriszen/wolkaraforever/issues). Do not share
account details, callbacks, tickets, signing or pairing files.
