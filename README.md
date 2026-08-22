# MacTray

The Windows tray, on the macOS menu bar. One arrow collapses every status icon that
does not fit and brings them back with a click.

![MacTray collapsed and expanded](docs/screenshot-bar.png)

## Why

macOS has no overflow area for menu bar items. Once the bar is full — and on a
MacBook the notch eats most of it — new status icons are silently dropped: they are
laid out to the left of everything else, which is exactly the region the notch and the
app menus cover. Nothing warns the user; the icon simply never shows up.

## How it works

There is no public API to hide another app's status item, so MacTray occupies the
space instead. It installs its own status items and grows one of them to 10 000 points,
which pushes everything to its left off screen:

```
[always hidden] (·separator·) [hidden] (|separator|) (‹ arrow)
```

- **collapsed** — the expand separator is huge, so everything left of it disappears;
- **expanded** — the separator shrinks back to 10 points and the icons return;
- **⌥ click** — also reveals the optional always-hidden section.

Two details make the difference between working and not working on a full bar:

1. **Preferred position.** A brand new status item is born at the far left, the part
   the notch covers, so on a saturated bar the app itself is invisible. MacTray seeds
   `NSStatusItem Preferred Position <name>` (the same key the system writes when you
   ⌘-drag an icon) so its items start next to the clock. Written only once — after
   that whatever the user dragged wins.
2. **Real hiding needs real space.** Since the arrow occupies a slot, installing
   MacTray on a completely full bar pushes one existing icon out. Turning the
   separator line off in Preferences gives 10 points back.

## Install

```bash
git clone https://github.com/NspxMiguel/MacTray.git
cd MacTray
./build.sh
cp -R build/MacTray.app /Applications/
open /Applications/MacTray.app
```

Requires macOS 14 or newer. The build produces a universal binary (arm64 + x86_64)
signed ad-hoc — no Apple Developer account needed.

## Using it

- **click the arrow** — show or hide the collapsed icons;
- **⌥ click** — reveal the always-hidden section too (enable it in Preferences);
- **right click** — Preferences, About, Quit;
- **⌘ drag any menu bar icon** — this is how you decide what gets hidden: whatever
  sits to the left of the arrow collapses, whatever sits to its right stays visible.

### Preferences

| Setting | Default |
| --- | --- |
| Open at login | off |
| Hide when clicking anywhere else | off |
| Auto-hide after N seconds | off, 10 s |
| Always-hidden area | off |
| Arrow icon (chevron, double chevron, triangle, dot) | chevron |
| Separator line while expanded | on |
| Global keyboard shortcut | none |
| Language (automatic, Português, English) | automatic |

### Command line

The binary doubles as a controller for Shortcuts, Raycast, Keyboard Maestro or a
plain script — it talks to the running instance and exits:

```bash
/Applications/MacTray.app/Contents/MacOS/MacTray --toggle
/Applications/MacTray.app/Contents/MacOS/MacTray --show
/Applications/MacTray.app/Contents/MacOS/MacTray --hide
/Applications/MacTray.app/Contents/MacOS/MacTray --show-all
/Applications/MacTray.app/Contents/MacOS/MacTray --preferences
```

### Language

Portuguese and English ship in the app. The system language decides the default, the
Appearance tab overrides it, and `MACTRAY_LANG=pt` (or `en`) forces one for a single
run:

```bash
MACTRAY_LANG=pt open /Applications/MacTray.app
```

## Permissions

None. No Accessibility, no Screen Recording. The global shortcut uses Carbon's
`RegisterEventHotKey` and the outside-click detection uses a global *mouse* monitor —
neither requires a TCC prompt.

## Build layout

| Path | What |
| --- | --- |
| `Sources/MacTray/TrayController.swift` | the status items and the hide/show logic |
| `Sources/MacTray/PreferencesView.swift` | SwiftUI preferences |
| `Sources/MacTray/L10n.swift` | pt/en strings |
| `Sources/MacTray/HotKey.swift` | Carbon global shortcut |
| `Sources/MacTray/RemoteCommand.swift` | CLI ↔ running instance |
| `Tools/makeicon.swift` | draws AppIcon.icns at build time |
| `build.sh` | universal build + bundle + ad-hoc signature |

## License

MIT.
