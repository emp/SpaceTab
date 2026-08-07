# SpaceTab

A Cmd+Tab-style app switcher for macOS that only lists apps with a window on the
**current Space**.

Built to stay responsive over high-latency screen sharing. It draws app icons and
a name on a flat panel — no window thumbnails, no screen capture, no blur by
default — so invoking it pushes a handful of solid blocks over the wire instead
of a full-frame recomposite.

<img src="Resources/icon.png" width="96" alt="SpaceTab icon">

## Why

The built-in macOS switcher lists every app across every Space. Thumbnail-based
switchers solve the Space problem but capture window previews to do it, which is
slow over a remote session. SpaceTab does neither: it asks the window server
which windows are on the displayed Space and draws their app icons.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`) — full Xcode not required

## Build and install

```sh
git clone https://github.com/emp/SpaceTab.git
cd SpaceTab
./install.sh
```

`install.sh` builds a release binary, assembles `SpaceTab.app`, installs it to
`/Applications`, and launches it. To build without installing, run `./build.sh`
and open `build/SpaceTab.app`.

The app lives in the menu bar and has no Dock icon. Quit it from there.

### Accessibility permission

Required, for two reasons: intercepting the trigger key before the focused app
sees it, and raising a specific window. On first launch SpaceTab opens System
Settings → Privacy & Security → Accessibility — enable **SpaceTab** there. It
picks up the grant within a second, no relaunch needed.

The menu bar icon shows a warning triangle while the hotkey is not live, and the
menu reads `Active` once it is.

## Usage

| Key | Action |
| --- | --- |
| `Option+Tab` | Open switcher / advance forward |
| `Option+Shift+Tab` | Move backward |
| `Option` + `←` `→` `↑` `↓` | Move selection |
| release `Option` | Switch to the selected app |
| `Escape` | Cancel |

Ordering is most-recently-used, so a single `Option+Tab` toggles between your
last two apps.

### Replacing the system Cmd+Tab

The menu has a **Replace Cmd+Tab** toggle. Switched on, the trigger becomes
`Cmd+Tab` and the built-in switcher never sees the keystroke — the chord above
works identically with Cmd substituted for Option.

Nothing about the system is modified, so every failure mode restores stock
behaviour on its own:

- Quit SpaceTab → Cmd+Tab is back immediately.
- The app crashes → the event tap dies with the process.
- The app stalls → macOS disables the tap on timeout and delivers Cmd+Tab to the
  system switcher; SpaceTab re-enables its tap once responsive.

If SpaceTab is ever wedged, `pkill -x SpaceTab` restores the system switcher.

### Blur background

Off by default. On, the panel uses the same `NSVisualEffectView` material as
native macOS panels. It looks closer to the system switcher but is the one
setting that works against remote responsiveness: a blurred backdrop
recomposites whatever is behind it, so the panel is a different image every time
it appears.

Both settings persist across launches.

## How it works

`CGWindowListCopyWindowInfo(.optionOnScreenOnly, …)` reports only windows on the
Space currently displayed, so Space filtering is free and needs no private Space
APIs. Results arrive in front-to-back z-order; entries are filtered to layer 0
and regular-activation-policy apps, then deduplicated per process.

Selecting an app raises its specific on-this-Space window through the
Accessibility API *before* calling `activate()`, so macOS does not switch Spaces
to show a different window of that app.

The trigger chord is consumed at a session-level `CGEventTap`. Session taps run
ahead of the WindowServer's symbolic hotkeys in the event pipeline, which is what
makes replacing Cmd+Tab possible.

### Caveats

- Matching an `AXUIElement` to a `CGWindowID` uses `_AXUIElementGetWindow`, a
  private API. It has been stable for over a decade and is the same call AltTab,
  yabai and Hammerspoon rely on, but it is not a supported interface.
- While macOS secure input is active (a password field has focus), event taps
  receive nothing, so the trigger falls through to default behaviour.
- Not sandboxed and not App Store eligible, for the two reasons above.

## Code signing and permission churn

`build.sh` ad-hoc signs by default. TCC binds an Accessibility grant for an
ad-hoc binary to its **cdhash**, which changes on every build. The old grant
lingers in System Settings as a checked box authorising a binary that no longer
exists, and re-toggling it merely re-grants that dead record. `build.sh`
therefore runs `tccutil reset Accessibility com.mp.spacetab` after an ad-hoc
build so you get one clean prompt that binds to the new binary.

To make the grant survive rebuilds, sign with a stable self-signed certificate —
TCC then matches on the designated requirement rather than the hash:

1. **Keychain Access** → **Certificate Assistant** → **Create a Certificate…**
2. Name `SpaceTab Signing`, Identity Type **Self Signed Root**, Certificate Type
   **Code Signing**.
3. Build with it:

   ```sh
   SPACETAB_SIGN_ID="SpaceTab Signing" ./build.sh
   ```

The reset is skipped when a real identity is used.

## Distribution

The bundle is ad-hoc signed and not notarized, so a copy downloaded from the
internet is quarantined and Gatekeeper will refuse it — on Sequoia the recipient
must approve it under System Settings → Privacy & Security. Distributing it
properly requires an Apple Developer ID certificate and notarization. Building
from source avoids all of this.

`build.sh` produces a native binary for the build machine's architecture. For a
universal build, add `--arch arm64 --arch x86_64` to the `swift build` call.

## Start at login

System Settings → General → Login Items → `+` → SpaceTab.

## License

MIT — see [LICENSE](LICENSE). Provided as is, without warranty of any kind.
