# SpaceTab

A Cmd+Tab-style app switcher for macOS that only lists apps with a window on the
**current Space**.

Built to stay responsive over high-latency screen sharing. 

<img src="Resources/icon.png" width="96" alt="SpaceTab icon">

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
`/Applications`, and launches it. 

To build without installing, run `./build.sh` and open `build/SpaceTab.app`.

The app lives in the menu bar and has no Dock icon. Quit it from there.

### Accessibility permission required

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

## Start at login

System Settings → General → Login Items → `+` → SpaceTab.

## License

MIT — see [LICENSE](LICENSE). Provided as is, without warranty of any kind.
