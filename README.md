# Delayed Shortcuts

A native macOS menu bar app for delayed alternative keyboard shortcuts. It listens for configured trigger shortcuts, waits for the configured delay, then posts the configured output shortcut.

The app is built with Swift and AppKit, runs as a status item near the clock, and does not require opening Xcode.

## What It Does

- Shows a small menu bar icon.
- Lets you enable or disable listening from the menu.
- Shows the configured shortcuts in a menu and in a small table window.
- Creates a user config at `~/Library/Application Support/DelayedShortcuts/shortcuts.json`.
- Ships with default delayed output shortcuts for the configured Hyper-symbol table.
- Requests Accessibility and Input Monitoring permissions on launch.
- Stays in `Not Ready`/permission-needed state until the required permissions are allowed.

## Default Shortcuts

The default shortcuts are:

| Trigger | Output | Output step delay |
| --- | --- | --- |
| `Ctrl+Opt+Cmd+Shift+!` | `Opt+1` | `151 ms` between `Opt` and `1` |
| `Ctrl+Opt+Cmd+Shift+@` | `Opt+2` | `151 ms` between `Opt` and `2` |
| `Ctrl+Opt+Cmd+Shift+\` | `Opt+3` | `151 ms` between `Opt` and `3` |
| `Ctrl+Opt+Cmd+Shift+$` | `Opt+Q` | `151 ms` between `Opt` and `Q` |
| `Ctrl+Opt+Cmd+Shift+%` | `Opt+W` | `151 ms` between `Opt` and `W` |
| `Ctrl+Opt+Cmd+Shift+&` | `Opt+E` | `151 ms` between `Opt` and `E` |
| `Ctrl+Opt+Cmd+Shift+*` | `Opt+Shift+L` | `150 ms` between `Opt`, `Shift`, and `L` |
| `Ctrl+Opt+Cmd+Shift+(` | `Opt+Shift+H` | `150 ms` between `Opt`, `Shift`, and `H` |

Each one consumes the trigger. Existing version `1` config files are migrated to this table automatically.

## Build

```bash
./scripts/build.sh
```

The built app is written to:

```text
/Users/winston/projects/delayed_shortcuts/tmp/DerivedData/Build/Products/Release/DelayedShortcuts.app
```

The build output defaults to `tmp/` inside this project so generated files are easy to find and clean up. Set `DELAYED_SHORTCUTS_BUILD_ROOT` if you want another output root.

By default the app is ad-hoc signed for local use. For distribution, set `DELAYED_SHORTCUTS_CODE_SIGN_IDENTITY` to a Developer ID Application identity.

## Run

```bash
open /Users/winston/projects/delayed_shortcuts/tmp/DerivedData/Build/Products/Release/DelayedShortcuts.app
```

The first launch asks for permissions. macOS may require you to quit and reopen the app after granting Accessibility or Input Monitoring.

The app enforces a single running instance. If you run `open` again while it is already running, the new copy exits immediately.

## Package Installer

```bash
./scripts/package.sh
```

The installer package is written to:

```text
/Users/winston/projects/delayed_shortcuts/tmp/DelayedShortcuts-0.1.0.pkg
```

For installing on other computers without warning dialogs, sign and notarize the app and package with a Developer ID certificate. The project currently uses local ad-hoc signing so it can build on this machine without Xcode UI setup.

To sign the installer package, set `DELAYED_SHORTCUTS_INSTALLER_SIGN_IDENTITY` to a Developer ID Installer identity before running `./scripts/package.sh`.

## Configure Shortcuts

Use the menu item `Open Config File`, edit `shortcuts.json`, then choose `Reload Config`.

Shortcut keys use strings such as:

- letters: `a`, `b`, `c`
- numbers: `0` through `9`
- symbols: `!`, `@`, `#`, `$`, `%`, `^`, `&`, `*`, `(`, `)`, `-`, `=`, `[`, `]`, `;`, `'`, `,`, `.`, `/`, `\`, and grave accent
- named keys: `space`, `tab`, `return`, `escape`, `delete`, `left`, `right`, `up`, `down`, `f1` through `f12`

Modifiers are:

- `command`
- `control`
- `option`
- `shift`
