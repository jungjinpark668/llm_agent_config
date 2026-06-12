---
date: 2026-06-11
tags: [macos, tooling, cmux]
type: log
status: completed
---

# cmux / macOS shortcut conflicts (resolved 2026-06-11)

Cmux 0.64.14 (`/Applications/cmux.app`, config at `~/.config/cmux/cmux.json`) default shortcuts collided with [[macos-symbolic-hotkeys]] on this machine. macOS system hotkeys always win over in-app shortcuts.

## Conflicts found

| Combo | macOS side | cmux side | Fix applied |
|---|---|---|---|
| Ctrl+1…5 | Switch to Desktop 1-5 (hotkey IDs 118-122, auto-enabled by Spaces) | selectSurfaceByNumber | Disabled macOS IDs 118-122 |
| Alt+Cmd+D | Turn Dock hiding on/off (ID 52) | splitBrowserRight | Disabled macOS ID 52 |
| Alt+Cmd+F | cmux registers it as a system-wide global hotkey, stealing find/replace from other apps | globalSearch | Rebound to `ctrl+alt+cmd+f` in cmux.json |
| Ctrl+Alt+Cmd+. | none | showHideAllWindows (global) | No change needed |

Non-issues: Cmd+Space / Ctrl+Space / Opt+Cmd+Space (input switching + Spotlight on this trilingual setup) — cmux binds nothing on Space.

## How it was done

- Disable a symbolic hotkey while keeping its key params: `defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add <ID> '{enabled = 0; value = {...original...}; }'` then `/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u` (logout/login as fallback).
- cmux overrides go in `shortcuts.bindings` keyed by action id; schema at `https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json`. Strings are case-insensitive (`ctrl+alt+cmd+f`); arrays make chords; `null`/`"unbound"` unbinds. Reload with Cmd+Shift+, inside cmux.

## Follow-up findings (same day)

- Disabling a Spaces hotkey in the plist does not release a registration the Dock already holds — Ctrl+1 stayed captured until `killall Dock`. Logout/login is the fallback.
- The Files right-sidebar panel (v0.64.14) has no bindable "open file" shortcut: the tree opens files by double-click only (`outlineView.doubleAction` in `Sources/FileExplorerView.swift`); tree keys are J/K / Ctrl+N/P / arrows (move), H/L (collapse/expand), `/` (type-ahead select), Esc. Return opens files only in the panel's search-box results flow.

## Revert

- macOS: System Settings → Keyboard → Keyboard Shortcuts → Mission Control (desktop switching) / Launchpad & Dock (Dock hiding), re-tick the boxes. Note: macOS may re-enable "Switch to Desktop n" when new Spaces are created.
- cmux: delete the `globalSearch` line from `~/.config/cmux/cmux.json`.
