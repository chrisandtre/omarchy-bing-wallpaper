# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

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
