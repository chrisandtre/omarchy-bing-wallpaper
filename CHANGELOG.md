# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.5.4] - 2026-09-14

### Security

- **Execution boundary.** Nothing is launched by bare name through an inherited
  `PATH` any more. The service starts `/usr/bin/bash` with a cleared
  environment and an explicit allowlist (`PATH` pinned to trusted system
  directories, plus only the session variables the theme, browser and
  notification helpers need); the script pins `PATH` again on its own side,
  drops the command hash, and resolves `curl`, `jq`, `file`, `head`, `stat` and
  `mv` to absolute paths under those directories. A writable directory early on
  somebody's `PATH` can no longer decide what an unattended refresh runs.
- **Lifecycle ownership.** Jobs run under `timeout`, which puts them in their
  own process group: a refresh has a 300 second deadline, `TERM` escalates to
  `KILL` after 10 seconds, and both reach everything the script spawned instead
  of orphaning it. The parallax daemon gets the same group with the deadline
  disabled, the script terminates its own background children on a signal, and
  the service tears both down when it is destroyed, so a shell restart no
  longer leaves a process tree behind.
- **Output ceilings.** The service collected the script's stderr into a buffer
  with no limit of its own. The script now caps its own stdout and stderr at
  64 KiB for the subcommands the service drives, draining past the ceiling
  rather than closing so a chatty helper still runs to completion.
- **One path for remote strings.** The bar widget and panel no longer launch a
  browser or a file manager themselves. Every action is a subcommand of
  `bin/bing-wallpaper` (`open`, the new `backgrounds`), so a link from Bing
  meets `sanitize_link` on one path however it was triggered, and the handler
  is resolved under the trusted directories rather than through `PATH`.

### Added

- `bing-wallpaper backgrounds` opens the generated backgrounds folder, and is
  what the panel's Wallpapers button now calls.

### Fixed

- The detail panel could not be closed, and held the pointer and keyboard
  hostage until the shell was restarted. Omarchy hands third-party plugins
  `PluginBarApi` as their `bar`, where `centerHoverRevealSuppressed` is
  readonly, so assigning to it threw and aborted `close()` before the panel
  state was cleared — leaving the panel's full-screen layer surface mapped and
  swallowing every click. The suppression now goes through
  `setCenterHoverRevealSuppressed()`, which both the plugin and first-party bar
  APIs provide.

## [0.5.3] - 2026-09-10

### Security

- Every network response now has a hard byte ceiling enforced at the producer:
  256 KiB for the metadata call, 25 MiB per picture, and the backgrounds folder
  as a whole is capped at 400 MiB. An oversized or endless response is cut off
  and discarded before `jq`, `file`, ImageMagick, Aether or the panel see any
  of it. Downloads are https-only, and the image path from the metadata must
  have the shape Bing uses.
- The story link from Bing's metadata is accepted only as an https URL on
  bing.com with no credentials or explicit port. It is checked before it is
  stored, again before `bing-wallpaper open` launches a browser, and once more
  in the panel and bar widget. Anything else shows no story button.

## [0.5.2] - 2026-09-04

### Changed

- The panel may grow taller on screens with room for it, so the screensaver
  settings added in 0.5.0 are not pushed below the fold.
- New screenshots: the screensaver in colour with depth and captions, and the
  panel with the new controls.

## [0.5.1] - 2026-09-04

### Fixed

- With `screensaverStyle` on `auto`, adding the `--existing-color-handling`
  flag to `omarchy-screensaver` now switches the art to colour on the next
  fetch instead of waiting for the next picture.

## [0.5.0] - 2026-09-04

### Added

- **Colour screensaver.** The art can now carry the photograph's own colours:
  every cell is written as a truecolor escape, so a blue sky, a green marsh and
  a red-and-white lighthouse read as exactly that, and the art matches the
  theme by construction since both come from the same pixels. `ttfx` keeps the
  colours only when `omarchy-screensaver` passes `--existing-color-handling`,
  which stock Omarchy 4.0 does not yet; see *Colour* in the README for the
  one-line change and how the plugin falls back to plain glyphs until then.
- **Depth.** The `depth` style finds the horizon, fades distant ground toward
  the sky's haze and gives near cells heavier glyphs, so a landscape has a
  foreground, a middle and a far away instead of one flat texture. Close-ups
  with no horizon are rendered flat, deliberately.
- **Parallax drift.** With `depth`, five frames shifted by distance are
  rendered and `bing-wallpaper parallax` (kept running by the service) swaps
  the next one in every time the screensaver begins a new effect, so the camera
  seems to drift slowly through the scene between dissolves. Off with
  `screensaverParallax`.
- **Caption.** The picture's title and place are centred under the art, so a
  lighthouse four cells wide still gets named. Off with `screensaverCaption`.
- `screensaverStyle` (`auto`, `depth`, `color`, `mono`; default `auto`), panel
  controls for style, caption and parallax, and `bing-wallpaper parallax
  [--step | --reset]`.

### Changed

- The screensaver is re-rendered when any screensaver setting changes, not
  only the size, and takes the fresh title and place when a new picture lands.
- `state.json` gains `screensaverStyle`, `screensaverStyleSetting`,
  `screensaverColor`, `screensaverCaption`, `screensaverParallax`,
  `screensaverFrames` and `screensaverSums`; the panel's status line says which
  style is actually on screen and why.

## [0.4.0] - 2026-09-03

### Added

- **The whole week from the first run.** One fetch now asks Bing for the last
  eight days and downloads the seven the plugin keeps, so the archive is full
  out of the box instead of filling up over a week. Today's picture is applied
  first; the rest come down behind it.
- **Palette previews.** The panel shows the week as a grid of pictures, each
  with a strip of the palette Aether would build from it. Click one to preview
  its picture and palette in the hero, then **Use this picture** (or Return)
  to switch wallpaper and theme to it; Escape goes back. Palettes are extracted
  once per mode and style and cached in `~/.local/state/bing-wallpaper/archive.json`,
  and recomputed when **Palette mode** or **Palette style** changes.
- `bing-wallpaper apply <date | id | days-ago>` switches to an archived picture
  from the terminal; `bing-wallpaper archive` prints the archive; `open` takes
  an optional picture. `fetch --date YYYY-MM-DD` is the underlying primitive.
- `omarchy-shell io.github.chrisandtre.bing-wallpaper apply <when>` IPC call.

### Fixed

- **Open story** and **Wallpapers** in the panel, and right-click on the bar
  pill, did nothing: they called a `shellQuote` helper the bar does not have,
  so the click handlers threw. They now launch through the shell's argv runner.

## [0.3.0] - 2026-09-03

### Added

- **Screensaver support, on by default.** Today's picture is rendered as ASCII
  art into `~/.config/omarchy/branding/screensaver.txt`, so the Omarchy
  screensaver dissolves the day's photograph instead of the logo, using the
  same random `ttfx` effects as before. `screensaverSize` picks the art size,
  and the toggle takes effect immediately rather than waiting for the next
  scheduled fetch.
- Because this is on by default, the plugin replaces the screensaver art on its
  first run. Whatever was there is copied to
  `~/.local/state/bing-wallpaper/screensaver.txt.orig` first and restored
  exactly when the setting is turned off, and art you have edited yourself is
  never overwritten.
- `bing-wallpaper install-deps` installs ImageMagick, which the screensaver
  needs and a stock Omarchy box does not necessarily have.
- Screensaver screenshots in the README

## [0.2.0] - 2026-09-03

### Added

- `bing-wallpaper fetch --day N` applies the picture (and theme) from up to
  seven days ago. The choice holds until tomorrow's image arrives.
- Showcase screenshots in the README

### Changed

- Renamed to "Bing Wallpaper & Theme" and explained how this differs from the
  other Bing wallpaper plugins in the marketplace

## [0.1.0] - 2026-09-03

### Added

- Daily fetch of the Bing image of the day for a configurable market
- Generated **Bing** theme built from each image with Aether, in dark, light,
  or automatic (light by day) palettes
- Bar widget showing the image title, with a detail panel: preview, credit,
  story link, refresh, wallpapers folder, and settings
- Background service with idempotent scheduling that survives suspend and
  offline stretches
- Seven-day image retention with automatic pruning
- Wallpaper-only mode for people who want to keep their own theme
- `bin/bing-wallpaper` CLI: `fetch`, `status`, `settings`, `set`, `open`, `next`
