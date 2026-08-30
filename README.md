# MacTray

The Windows tray, on the macOS menu bar. One arrow collapses every status icon that
does not fit and brings them back with a click.

![MacTray collapsed and expanded](docs/screenshot-bar.png)

## Why

macOS has no overflow area for menu bar items. Once the bar is full — and on a
MacBook the notch eats most of it — new status icons are silently dropped: they are
laid out to the left of everything else, which is exactly the region the notch and the
app menus cover. Nothing warns the user; the icon simply never shows up.

## The tray

Clicking the arrow opens a panel under it with the icons that are not on the bar —
the Windows tray. Each one shows the app it belongs to; clicking it opens that app's
menu, wherever the icon actually sits.

![The tray panel](docs/screenshot-tray.png)

This is what a full bar on a MacBook really needs. Expanding back onto the bar only
helps while there is room: past that, macOS lays the extra icons out under the notch,
where they are neither visible nor clickable — a synthetic click there hits nothing.
The panel does not care about that geometry.

Reading other apps' menu bar items requires the **Accessibility** permission, and only
for the panel: with it off, the arrow still collapses and expands the bar, no permission
involved. The panel asks for it the first time, and explains why before the system
dialog shows up.

Clicking an icon in the panel does what clicking it on the bar would do — including
for icons parked under the notch, which no mouse click can reach.

The first accessibility press an app receives usually comes back "action not
supported"; the next one works. Apps build their accessibility tree when something
first asks, and the action shows up a moment later. MacTray retries for about eight
tenths of a second, which is what made Ollama, Docker and ChatGPT open from the panel
at all. If every attempt fails and the icon happens to be in the clickable part of the
bar, a synthetic click takes over; if it fails under the notch, the owning app is
brought to the front instead.

Note that the press is a *left* click. Apps that use the left click for an action
rather than a menu behave accordingly — Shottr takes a screenshot, exactly as it would
if you clicked it on the bar.

Three implementation notes, all measured rather than assumed:

- every icon on the bar belongs to the Control Center process as far as the window
  server is concerned, so `CGWindowList` cannot tell you who owns what. The
  `AXExtrasMenuBar` attribute of each running app can;
- an item only accepts the press once the bar has laid it out, so the bar is expanded
  first and the panel waits for the icon to actually appear before acting on it. The
  accessibility element captured while the bar was collapsed goes stale across that
  relayout and has to be read again, or the press fails;
- the bar is only restored *after* the menu closes — collapsing while a menu is open
  takes its owner out of the layout and shuts the menu. `AXSelected` on the item is the
  signal for that: there is no window to observe.

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
brew install --cask nspxmiguel/tap/mactray
```

The cask downloads the source and builds it on your machine, so the binary never
carries a quarantine attribute and Gatekeeper stays quiet. It installs the Xcode
Command Line Tools first if they are missing.

Building by hand works too, and is the path to take when changing the code:

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

### Choosing what stays on the bar

The **Icons** tab lists everything on the menu bar in two groups — what stays on the bar
and what lives in the tray — with a button to move an icon between them.

The two directions work differently, because macOS only accepts one of them:

- **Send to the tray** drags the icon to the left of the arrow, the same ⌘ drag you would
  do by hand. Synthetic drags to the *left* work; to the right the system ignores them,
  which is why the other direction takes another route.
- **Keep on the bar** moves the arrow to just before that icon instead, by writing its
  preferred position and recreating the item. Anything to the right of the icon therefore
  stays on the bar too — with a full bar that is geometry, not a choice: an icon cannot
  become visible while the ones between it and the arrow stay hidden.

An icon parked under the notch cannot be dragged at all — nothing can grab what the
system does not draw — so *Send to the tray* reports that instead of pretending.

Both are also on the command line:

```bash
/Applications/MacTray.app/Contents/MacOS/MacTray --pin Docker
/Applications/MacTray.app/Contents/MacOS/MacTray --unpin Figma
```

The arrow travels with the boundary, staying just to its left — before the pinned
icons, like the Windows arrow. Parking it at the right edge instead put the pinned icons
between the arrow and the panel, so the panel opened underneath them.

Reading the bar means asking every running process whether it owns menu bar items, which
on a normal machine is ~170 questions and takes about half a second — far too much to do
on every click. Apps that answered yes are remembered and are the only ones asked on the
fast path (~15 ms); the full sweep runs in the background every 20 seconds, six at a
time, because each accessibility call blocks its thread and letting GCD open one per app
stalled the whole machine.

Two things worth knowing about that preferred position key: macOS deletes it when the
status item goes away, so the chosen boundary is kept in MacTray's own preferences and
written back on every launch; and the deletion lands *after* the removal, so the
rewrite has to happen on the next run loop pass or it is lost.

### Preferences

| Setting | Default |
| --- | --- |
| Clicking the arrow opens the tray | on |
| Animate the arrow on click | on |
| Open at login | off |
| Show in the Dock and in the app list | off |
| Hide when clicking anywhere else | off |
| Auto-hide after N seconds | off, 10 s |
| Always-hidden area | off |
| Arrow icon (chevron, double chevron, triangle, dot) | chevron, pointing down |
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

`--open <app>` opens the menu of a hidden icon by name, and `--list` prints what
MacTray is reading from the bar (useful when an icon does not show up in the panel):

```bash
/Applications/MacTray.app/Contents/MacOS/MacTray --panel
/Applications/MacTray.app/Contents/MacOS/MacTray --open Docker
/Applications/MacTray.app/Contents/MacOS/MacTray --list
```

`--login-item on|off` runs in the calling process instead of signalling the running
instance, because `SMAppService` registers the bundle of whoever calls it — that is the
path macOS opens at login:

```bash
/Applications/MacTray.app/Contents/MacOS/MacTray --login-item on
```

`--dock on|off` switches the app between accessory and regular. Off — the default —
keeps MacTray out of the Dock and the app switcher, which is what a menu bar app
usually wants; it also keeps the app out of the system's list of running
applications, so tools that enumerate apps never see it. Turn it on when you need
MacTray to show up there:

```bash
/Applications/MacTray.app/Contents/MacOS/MacTray --dock on
```

### Language

Portuguese and English ship in the app. The system language decides the default, the
Appearance tab overrides it, and `MACTRAY_LANG=pt` (or `en`) forces one for a single
run:

```bash
MACTRAY_LANG=pt open /Applications/MacTray.app
```

## Permissions

The tray panel needs **Accessibility** — it is the only way macOS lets an app read
other apps' menu bar items and open their menus. Nothing else does: the global
shortcut uses Carbon's `RegisterEventHotKey`, the outside-click detection uses a
global *mouse* monitor, and hiding icons is just status item geometry. No Screen
Recording at any point.

Turn the panel off in Preferences and MacTray asks for nothing at all.

Accessibility is granted to a *signature*, not to a path. An ad-hoc signature carries
a fresh code hash on every build, so macOS treats each build as a different app and
drops the approval — after every update the panel would come up empty until the
permission was granted again. `build.sh` therefore signs with a local certificate
when one is present, which pins the designated requirement to the certificate
instead of the hash:

```bash
codesign -d -r- /Applications/MacTray.app
# designated => identifier "dev.nspx.MacTray" and certificate root = H"…"
```

Creating that certificate is optional and local to the machine that builds; without
it the build falls back to ad-hoc, which is what a Homebrew install uses.

### Log

MacTray writes to `~/Library/Logs/MacTray.log`: what it found at startup
(accessibility, clickable area, boundary), every icon move, and every time it had to
pull the arrow back into reach. `NSLog` from a sandboxless accessory app does not
reach the unified log, and a menu bar defect only shows up on the bar of whoever is
using it — the file is what makes that debuggable.

```bash
tail -f ~/Library/Logs/MacTray.log
```

## Build layout

| Path | What |
| --- | --- |
| `Sources/MacTray/TrayController.swift` | the status items and the hide/show logic |
| `Sources/MacTray/TrayPanel.swift` | the tray panel |
| `Sources/MacTray/MenuBarScanner.swift` | reads the bar through Accessibility |
| `Sources/MacTray/ItemActivator.swift` | opens a hidden icon's menu |
| `Sources/MacTray/PreferencesView.swift` | SwiftUI preferences |
| `Sources/MacTray/L10n.swift` | pt/en strings |
| `Sources/MacTray/HotKey.swift` | Carbon global shortcut |
| `Sources/MacTray/RemoteCommand.swift` | CLI ↔ running instance |
| `Tools/makeicon.swift` | draws AppIcon.icns at build time |
| `build.sh` | universal build + bundle + ad-hoc signature |

## License

MIT.
