# ConsoleMode

A **Theos/Logos jailbreak tweak project** targeting a rootless,
arm64/arm64e iPhone environment, including iOS 17.3 where an appropriate
jailbreak and tweak-injection system are available. This project does not
jailbreak a device, is not an App Store application, and is not device-tested.

## Requested target: iPhone XS Max with Dopamine

The requested device is an **iPhone XS Max (A12/arm64e), iOS 17.3, Dopamine**,
with **Sileo 3.x** reported as its package manager. Sileo and Dopamine are
separate components; the Sileo version is not the installed Dopamine version.
The current [official Dopamine support page](https://ellekit.space/dopamine/)
lists this device/OS combination within its supported ranges and describes
Dopamine as rootless. This does **not** verify this tweak's private API behavior.

This project consequently uses:

- Theos rootless packaging and Debian architecture `iphoneos-arm64`.
- `arm64` and `arm64e` slices, including the modern arm64e ABI needed by
  SpringBoard on the XS Max.
- ElleKit as the device injection dependency. Logos links the substrate-compatible
  API provided by the jailbreak environment; **do not install old Cydia
  Substrate merely because the build library is named `substrate`.**
- PreferenceLoader for the Settings pane.

## Important compatibility limits

**Do not treat this as a verified iOS 17.3 release.** Exact iPhone model,
jailbreak, injection framework, SDK, and SpringBoard implementation must be
checked on the target device.

- The landscape-only navigation controller, UIKit orientation hooks, and
  scene-geometry request enforce the console's requested orientation **when
  SpringBoard accepts those requests**. There is no public API for a
  device-wide iOS rotation lock. The private `UIDevice setOrientation:` call
  is guarded, but may be missing, ignored, or behave differently on iOS 17.
  **Guaranteed device-wide landscape enforcement is not established here.**
- The tweak injects only into SpringBoard. It does not alter the orientation
  policies of unrelated app processes or override every system screen.
- Unlock detection probes private `SBLockScreenManager` / `CSLockScreenManager`
  singleton lock-state selectors once per second, with UIKit notifications
  for faster refresh. Those classes and selectors are version-dependent.
  The public protected-data fallback cannot reliably detect every unlock,
  particularly on a phone without a passcode.
- The launcher is a SpringBoard-owned window, not a separately launched app.
  Scene availability and its ordering relative to lock screens, system alerts,
  and another foreground app must be verified on the target device. It never
  authenticates the user or bypasses the lock screen.
- Rootless packaging uses Theos-managed install prefixes and rpaths, including
  relocated-bootstrap support from current Theos. A rootful jailbreak requires
  a separate packaging configuration, not simply installing this rootless package.
- PreferenceLoader and the private Preferences framework must be compatible
   with the device. The preference controller uses the standard private
   Preferences headers from Theos; no preference helper library is required.

## Features implemented

- Four large game tiles: Cubik Game, Bloo, Kintic, and XP-OS.
- Each game runs in `WKWebView` inside the console window, never Safari.
- JavaScript, local website cookies/storage, normal HTTPS loading, popups
  redirected into the same web view, and JavaScript alert/confirm/prompt dialogs.
- WebKit element fullscreen is enabled when its preference setter is available;
  media playback uses normal WKWebView behavior. Actual fullscreen availability
  remains WebKit/site-dependent. The console does not inject scripts or rewrite
  websites to simulate unsupported browser capabilities.
- Edge-to-edge web view with a small floating **Console / Back** control.
  The Console control remains usable even with no browser history or when
  a game was auto-opened after unlocking.
- Optional auto-open URL; blank means the game-selection screen.
- Settings inside the launcher and a PreferenceLoader pane under
  **Settings → ConsoleMode**.
- Disable hides the overlay and returns the orientation hooks to their original
  behavior. The system rotation-lock preference is not modified.
- No analytics, browsing-history export, URL logging, proxy, or custom tracking.
  Websites themselves may collect information under their own policies;
  ordinary WKWebView cookies and website storage remain local to the device.

## Files

```text
Makefile                         Rootless tweak + preference-bundle build
control                          Debian package metadata
ConsoleMode.plist                 SpringBoard-only injection filter
Tweak.xm                         Orientation hooks and unlock monitor
ConsoleMode/CMPreferences.*       Preference validation and orientation requests
ConsoleMode/CMUI.*                Launcher, settings, WKWebView, console window
ConsoleModePrefs/                 PreferenceLoader Settings bundle
layout/Library/PreferenceLoader/  PreferenceLoader menu entry
preferences.example.plist        Editable preference-file example
```

## Build prerequisites

For the XS Max, use **macOS with Xcode's command-line tools and a current Theos
installation**. The modern arm64e ABI is required for this SpringBoard target.
Theos documents macOS/Xcode as the straightforward supported build path;
a generic Linux iOS compiler is not sufficient merely because it can emit
an arm64e slice. See [Theos rootless documentation](https://theos.dev/docs/rootless).

The build host needs:

1. A current Theos installation, its Logos tool, and an iOS cross-compilation
   toolchain.
2. A patched iOS SDK supporting UIKit scene geometry APIs and the private
   Preferences framework. The manual workflow uses Theos's iPhoneOS 16.5 SDK,
   which can build this code for deployment on iOS 17.3. SDK version and device
   OS version do not have to be identical.
3. SDK/linker support for the private Preferences framework.
4. Theos substrate headers/library and Debian packaging tools.

The Replit environment used to author this project has **no configured Theos
installation or iOS SDK**. Rootless packages have been compiled successfully
using the macOS GitHub Actions workflow. A successful build does not establish
that all private APIs or console behaviors work on the target device.

```sh
export THEOS=/path/to/theos
cd consolemode
make clean
make package FINALPACKAGE=1
```

### Manual GitHub Actions build

The repository includes `.github/workflows/build-consolemode.yml`. It is
**manual-only** (`workflow_dispatch`) and does not deploy or install anything.

If this repository is placed on GitHub:

1. Open **Actions → Build ConsoleMode package → Run workflow**.
2. The workflow uses a macOS runner with Xcode, installs Theos and the patched
   iOS 16.5 SDK, then runs the rootless Theos build.
3. If compilation succeeds, download the `ConsoleMode-rootless-deb` artifact.
4. If it fails, review the compiler output before attempting installation.

Running the workflow uses your GitHub Actions allowance. Builds must be
started explicitly; committing code alone does not start this workflow.

The resulting package is written to `packages/`. The project defaults to
`THEOS_PACKAGE_SCHEME=rootless` and `ARCHS="arm64 arm64e"`. Verify each `.deb`
build by running it with the prerequisites above.

## Install and use

1. Keep jailbreak safe-mode/recovery access available before installing any
   SpringBoard tweak.
2. Transfer the built package to the **already jailbroken, compatible** phone
   and install with its package manager, resolving PreferenceLoader and tweak
   injection dependencies (ElleKit and PreferenceLoader on Dopamine).
3. Respring using the jailbreak's supported mechanism.
4. Open **Settings → ConsoleMode**. The tweak starts **disabled** for safety.
5. Enable it, choose the landscape direction, and optionally set an auto-open
   URL. Lock and unlock the phone to enter the console.
6. Tap a tile to play. **Console** returns to selection; **Back** navigates
   website history, or returns to the launcher when there is no history.
7. **Disable ConsoleMode** closes the console and disables subsequent unlock
   launches. Re-enable under **Settings → ConsoleMode**, then lock/unlock.

The default destinations are:

- `https://cubik-game.replit.app`
- `https://bloo.watch`
- `https://kintic.site`
- `https://xp-os.replit.app`

## Preference file

Domain: `com.cubik.consolemode`. Settings and the in-console form use
Core Foundation preferences. In the usual mobile-user environment the
persisted file is:

```text
/var/mobile/Library/Preferences/com.cubik.consolemode.plist
```

It is created when a setting is written; code defaults apply before that.
`preferences.example.plist` shows every supported key. It is deliberately not
installed over an existing preference file during package upgrades.

| Key | Type | Default |
| --- | --- | --- |
| `enabled` | Boolean | false |
| `orientation` | String | `landscapeLeft` (`landscapeRight` is also accepted) |
| `autoLaunchURL` | String | Empty: show launcher |
| `gameURL0` ... `gameURL3` | HTTP(S) URL strings | The four URLs above |

Use Settings or the console form rather than editing the cached preference
file while processes are running. If you edit the plist directly, keep it
owned by the mobile user and respring/relaunch the relevant processes so
`cfprefsd` caches do not retain old values. Invalid stored URLs fall back to
the corresponding default; the in-console form rejects invalid input before
writing any URLs.

## On-device verification checklist

Before treating the package as usable, verify:

- Clean Theos build, correct rootless file paths, and PreferenceLoader pane load.
- Enable/disable/re-enable without a SpringBoard crash or repeated launch loop.
- Locked phone never exposes an interactive console before successful unlock.
- Unlock from both the Home Screen and a previously foregrounded app.
- Landscape left/right, sensor rotation, rotation lock already enabled, and
  restoration after disabling.
- All four live sites, touch interaction, cookies, JavaScript dialogs, and
  browser history.
- Fullscreen video / `requestFullscreen()` only where supported by WebKit.
- Auto-opened game can always return to selection and disable the tweak.
- Network failure shows Retry / Console, rather than trapping the user.

If the UI or lock-state API is incompatible, disable/remove the tweak through
the jailbreak's safe mode/package manager. Do not repeatedly respring into an
unstable configuration. Package identifier: `com.cubik.consolemode`.
