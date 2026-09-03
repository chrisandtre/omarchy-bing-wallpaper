<div align="center">

# Bing Wallpaper for Omarchy

**The Bing image of the day as your wallpaper, with a matching theme built from its colors every morning.**

[![CI](https://github.com/chrisandtre/omarchy-bing-wallpaper/actions/workflows/ci.yml/badge.svg)](https://github.com/chrisandtre/omarchy-bing-wallpaper/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Omarchy 4](https://img.shields.io/badge/Omarchy-4.x-4c1.svg)](https://omarchy.org)
[![Theme by Aether](https://img.shields.io/badge/theme%20by-Aether-8a5cf5.svg)](https://github.com/omacom/aether)

<img src="preview.png" alt="The bar pill showing today's title, and the detail panel with the picture, credit, actions and settings" width="720">

</div>

If you liked having Bing's daily photo on your Windows desktop, this brings it
to Omarchy and goes one better: every day the whole desktop is re-themed to
match the picture. A bar widget shows the title; click it for the story behind
the image, the photographer's credit, and the plugin's settings.

## Features

- **New picture every morning** in the Bing region you choose (14 markets, US default)
- **Matching theme** generated with [Aether](https://github.com/omacom/aether) and
  applied as an ordinary Omarchy theme named **Bing**
- **Dark, light, or auto** palettes; auto is light during the day and dark at night
- **A week of images** kept in the theme's backgrounds folder, older ones pruned
- **Robust scheduling**: knows when Bing's next image is due, survives suspend and
  offline stretches, never hammers the API
- **Wallpaper-only mode** if you would rather keep your own theme
- **No sudo or pkexec is required.** Everything happens in your home directory.

## Requirements

| Dependency | Why | Notes |
|------------|-----|-------|
| Omarchy 4.x | Quickshell-based `omarchy-shell` plugin host | The plugin is a standard shell plugin |
| `curl`, `jq`, `file` | Fetching and parsing Bing's API, checking downloads | Present on every stock Omarchy install |
| [Aether](https://github.com/omacom/aether) | Extracting a palette from each picture | Optional. Without it the plugin sets the wallpaper only and says so in the panel. `omarchy pkg aur add aether` |

## Install

```bash
omarchy plugin add https://github.com/chrisandtre/omarchy-bing-wallpaper.git --enable
```

You will be asked which bar section to place the widget in (center by default).
Enabling the widget also starts the background service. About eight seconds
later the first picture is fetched, the **Bing** theme is created under
`~/.config/omarchy/themes/bing`, and your desktop switches to it.

Move the widget later with `omarchy bar move io.github.chrisandtre.bing-wallpaper --section right`, and
disable or remove it from `Omarchy Menu > Setup > Plugins`.

## Using it

| Action | How |
|--------|-----|
| Show the picture, credit and settings | Left-click the bar pill |
| Refresh now | Middle-click the pill, or **Refresh** in the panel |
| Read today's story on Bing | Right-click the pill, or **Open story** |
| Open this week's images | **Wallpapers** in the panel |
| Cycle through the week's images | `omarchy theme bg next` |
| From a script or keybinding | `omarchy-shell io.github.chrisandtre.bing-wallpaper refresh` |

## Settings

The panel has the settings most people touch: region, palette mode, palette
style, and the re-theme switch. They are stored inline on the widget's entry in
`~/.config/omarchy/shell.json`, the same way every Omarchy bar widget stores its
options, so nothing else on your system is modified.

| Setting | Default | Meaning |
|---------|---------|---------|
| `market` | `en-US` | Bing region: `en-GB`, `en-CA`, `fr-CA`, `en-AU`, `en-NZ`, `en-IN`, `de-DE`, `fr-FR`, `es-ES`, `it-IT`, `pt-BR`, `ja-JP`, `zh-CN` |
| `mode` | `dark` | `dark`, `light`, or `auto` (light between `lightStart` and `lightEnd`) |
| `lightStart` | `7` | Hour (0-23) when `auto` switches to the light palette |
| `lightEnd` | `19` | Hour (0-24) when `auto` switches back to dark |
| `extractMode` | `normal` | Aether extraction mode: `normal`, `colorful`, `muted`, `pastel`, `bright`, `material`, `analogous`, `monochromatic`, `high-contrast` |
| `applyTheme` | `true` | `false` keeps your current theme and only sets the wallpaper |
| `retentionDays` | `7` | How many days of images to keep |
| `notify` | `true` | Desktop notification when a new picture lands |
| `resolution` | `UHD` | Preferred download size; falls back to `1920x1200`, then `1920x1080` |
| `showTitle` | `true` | Show the title next to the icon in the bar |
| `maxTitleChars` | `28` | Truncate long titles in the bar |

Example entry in `shell.json`:

```json
{ "id": "io.github.chrisandtre.bing-wallpaper", "market": "en-GB", "mode": "auto", "extractMode": "muted" }
```

The bundled CLI edits the same entry:

```bash
~/.config/omarchy/plugins/io.github.chrisandtre.bing-wallpaper/bin/bing-wallpaper set market en-GB
~/.config/omarchy/plugins/io.github.chrisandtre.bing-wallpaper/bin/bing-wallpaper set mode auto
```

## How it works

```
Service.qml ── every 15 min ──▶ bin/bing-wallpaper fetch
                                      │
                                      ├─ Bing HPImageArchive API (title, credit, story link)
                                      ├─ download the JPEG ─▶ ~/.config/omarchy/themes/bing/backgrounds/
                                      ├─ aether --generate --no-apply ─▶ colors.toml (normalized for Omarchy)
                                      ├─ omarchy theme set bing ; omarchy theme bg set <today>
                                      └─ ~/.local/state/bing-wallpaper/state.json
                                                   ▲
BarWidget.qml + Panel.qml ── watch ───────────────┘
```

The fetch is idempotent. It records when Bing's next picture is due and does
nothing until then, unless a setting changed or you asked for a refresh. Theme
application, which restarts terminals and re-tints apps exactly like
`omarchy theme set`, only happens when the picture or palette actually changed.

## What it touches

For people who like to know before they install:

- **Network:** `www.bing.com` only, for the daily metadata and the image.
- **Writes:** `~/.config/omarchy/themes/bing/` (the generated theme and images),
  `~/.local/state/bing-wallpaper/state.json`, and its own entry in
  `~/.config/omarchy/shell.json`. Omarchy's own theme machinery then updates the
  usual per-app theme files, as it does for any theme switch.
- **Runs:** `curl`, `jq`, `file`, `aether`, and Omarchy's `omarchy-theme-set`,
  `omarchy-theme-bg-set`, `omarchy-notification-send`, `omarchy-launch-browser`.
- **Privileges:** none. No sudo or pkexec is required.

## CLI

```
bing-wallpaper fetch [--force] [--market MKT] [--mode dark|light|auto]
bing-wallpaper status        # contents of state.json
bing-wallpaper settings      # effective settings
bing-wallpaper set KEY VALUE # update a setting in shell.json
bing-wallpaper open          # open today's story in the browser
bing-wallpaper next          # when the next check is due
```

Every setting can be overridden per invocation with `BING_WALLPAPER_<KEY>`,
for example `BING_WALLPAPER_MARKET=ja-JP bing-wallpaper fetch --force`.

## Uninstall

```bash
omarchy plugin remove io.github.chrisandtre.bing-wallpaper       # removes the widget and stops the service
omarchy theme set tokyo-night           # or any theme you like
rm -rf ~/.config/omarchy/themes/bing ~/.local/state/bing-wallpaper
```

## Development

```bash
git clone https://github.com/chrisandtre/omarchy-bing-wallpaper.git ~/Work/omarchy-bing-wallpaper
ln -s ~/Work/omarchy-bing-wallpaper ~/.config/omarchy/plugins/io.github.chrisandtre.bing-wallpaper
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.chrisandtre.bing-wallpaper
```

Edits made through the symlink do not hot-reload; run
`omarchy-shell shell rescanPlugins` after changing QML, and
`omarchy restart shell` after changing `Model.js` (the QML engine caches
JavaScript libraries). Validate before pushing with
`omarchy plugin validate ~/Work/omarchy-bing-wallpaper`; CI runs the same
manifest checks plus ShellCheck.

## Contributing

Issues and pull requests are welcome. Please keep the three places that define
settings in sync: `bin/bing-wallpaper` (defaults and validation), `Model.js`
(labels shown in the panel), and this README.

## License

[MIT](LICENSE). Bing images remain the property of their respective
photographers and agencies; the credit shown in the panel comes straight from
Bing, and this project is not affiliated with Microsoft or Bing.
