# SpaceTab

A Cmd+Tab-style app switcher for macOS that only lists apps with a window on the
**current Space**.



https://github.com/user-attachments/assets/2106621e-0c17-4865-85ac-210dd67ea21f



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

<img width="272" height="293" alt="image" src="https://github.com/user-attachments/assets/1fcc5b3e-b759-4127-af0b-b24f321c1553" />


Note: A few screen sharing apps are excluded from it - you can modify the list via the menu bar. So you can still CMD+Tab inside a Screen Sharing machine for example.

## Start at login

System Settings → General → Login Items → `+` → SpaceTab.

## License

MIT — see [LICENSE](LICENSE). Provided as is, without warranty of any kind.
