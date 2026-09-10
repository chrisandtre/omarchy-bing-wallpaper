.pragma library

// Shared, UI-free helpers for the Bing Wallpaper plugin. Settings names and
// defaults mirror bin/bing-wallpaper; keep the three in sync.

var PLUGIN_ID = "io.github.chrisandtre.bing-wallpaper"
var ICON = "󰋩"          // nf-md-image

var MARKETS = [
  { value: "en-US", label: "United States" },
  { value: "en-GB", label: "United Kingdom" },
  { value: "en-CA", label: "Canada" },
  { value: "fr-CA", label: "Canada (French)" },
  { value: "en-AU", label: "Australia" },
  { value: "en-NZ", label: "New Zealand" },
  { value: "en-IN", label: "India" },
  { value: "de-DE", label: "Germany" },
  { value: "fr-FR", label: "France" },
  { value: "es-ES", label: "Spain" },
  { value: "it-IT", label: "Italy" },
  { value: "pt-BR", label: "Brazil" },
  { value: "ja-JP", label: "Japan" },
  { value: "zh-CN", label: "China" }
]

var MODES = [
  { value: "dark", label: "Dark" },
  { value: "light", label: "Light" },
  { value: "auto", label: "Auto (light by day)" }
]

var EXTRACT_MODES = [
  { value: "normal", label: "Normal (faithful)" },
  { value: "colorful", label: "Colorful" },
  { value: "muted", label: "Muted" },
  { value: "pastel", label: "Pastel" },
  { value: "bright", label: "Bright" },
  { value: "material", label: "Material" },
  { value: "analogous", label: "Analogous" },
  { value: "monochromatic", label: "Monochromatic" },
  { value: "high-contrast", label: "High contrast" }
]

// Terminal cells are about 2.3x taller than they are wide, so a 16:9 picture
// needs roughly four times as many columns as rows to look square. These all
// hold that ratio. "Medium" is the default because it still fits the smallest
// canvas worth planning for -- a 1080p screen at the screensaver's font size
// is about 133x32 cells.
// "auto" is colour with depth wherever Omarchy's screensaver keeps colour, and
// plain glyphs where it does not (see README, "Colour").
var SCREENSAVER_STYLES = [
  { value: "auto", label: "Auto" },
  { value: "depth", label: "Colour with depth" },
  { value: "color", label: "Colour" },
  { value: "mono", label: "Plain glyphs" }
]

var SCREENSAVER_SIZES = [
  { value: "80x20", label: "Small" },
  { value: "120x29", label: "Medium" },
  { value: "160x39", label: "Large" },
  { value: "200x48", label: "Extra large" }
]

// The story link is validated by bin/bing-wallpaper before it reaches state,
// and again here before it reaches a browser: https, bing.com, nothing else.
function safeLink(link) {
  var s = String(link || "")
  return /^https:\/\/(www\.)?bing\.com(\/[\x21-\x7e]*)?$/.test(s) && s.split("/")[2].indexOf("@") < 0 ? s : ""
}

function parseState(text) {
  try {
    var parsed = JSON.parse(String(text || ""))
    return parsed && typeof parsed === "object" ? parsed : {}
  } catch (e) {
    return {}
  }
}

function optionLabel(options, value, fallback) {
  for (var i = 0; i < options.length; i++) {
    if (options[i].value === value) return options[i].label
  }
  return fallback !== undefined ? fallback : String(value || "")
}

function truncate(text, max) {
  var s = String(text || "")
  if (max <= 0 || s.length <= max) return s
  return s.slice(0, Math.max(1, max - 1)).replace(/\s+$/, "") + "…"
}

// Text shown in the bar pill.
function barLabel(state, showTitle, maxChars) {
  var title = state && state.title ? String(state.title) : ""
  if (!showTitle || title === "") return ICON
  return ICON + "  " + truncate(title, maxChars)
}

// "Wednesday, September 3" style date from the state's YYYY-MM-DD.
function prettyDate(iso) {
  if (!iso) return ""
  var parts = String(iso).split("-")
  if (parts.length !== 3) return String(iso)
  var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
  return Qt.formatDate(d, "dddd, MMMM d")
}

// "Today", "Yesterday", then the weekday, for the archive cards.
function dayLabel(iso) {
  if (!iso) return ""
  var parts = String(iso).split("-")
  if (parts.length !== 3) return String(iso)
  var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
  var now = new Date()
  var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  var diff = Math.round((today.getTime() - d.getTime()) / 86400000)
  if (diff === 0) return "Today"
  if (diff === 1) return "Yesterday"
  return Qt.formatDate(d, "ddd")
}

// Copyright strings look like "Place, Country (© Photographer/Agency)".
function splitCopyright(copyright) {
  var s = String(copyright || "")
  var m = s.match(/^(.*?)\s*\((©[^)]*)\)\s*$/)
  if (!m) return { place: s, credit: "" }
  return { place: m[1], credit: m[2] }
}

function statusLine(state) {
  if (!state || !state.status) return "Waiting for first fetch…"
  if (state.status === "fetching") return "Fetching today's image…"
  if (state.status === "error") return state.error || "Something went wrong"
  var theme = String(state.theme || "")
  if (theme === "aether-missing") return "Aether is not installed; wallpaper only"
  if (theme === "failed" || theme === "apply-failed") return "Theme generation failed; wallpaper only"
  if (state.applyTheme === false || state.applyTheme === "false") return "Wallpaper only (re-theming is off)"
  return "Theme and wallpaper up to date"
}

// Second status line, only when the screensaver has something to say.
function screensaverLine(state) {
  if (!state) return ""
  var status = String(state.screensaver || "")
  if (status === "magick-missing")
    return "Screensaver needs ImageMagick — run: bing-wallpaper install-deps"
  if (status === "failed") return "Screensaver art could not be rendered"
  if (status !== "applied") return ""
  var style = String(state.screensaverStyle || "mono")
  var wanted = String(state.screensaverStyleSetting || "auto")
  var color = state.screensaverColor === true || state.screensaverColor === "true"
  var parallax = state.screensaverParallax === true || state.screensaverParallax === "true"
  if (style === "mono" && wanted === "auto" && !color)
    return "Screensaver shows today's picture in plain glyphs; colour needs Omarchy's ttfx colour flag (see README)"
  if (style !== "mono" && !color)
    return "Screensaver art is in colour, but this Omarchy strips colour (see README)"
  if (style === "depth")
    return "Screensaver shows today's picture in colour with depth" + (parallax ? ", drifting between effects" : "")
  if (style === "color") return "Screensaver shows today's picture in colour"
  return "Screensaver shows today's picture"
}

// The chips drawn under a picture to preview its theme: the background with
// "Aa" in the foreground colour, then the accent and the six ANSI hues.
var SWATCH_KEYS = ["background", "accent", "color1", "color2", "color3", "color4", "color5", "color6"]

function swatches(colors) {
  if (!colors || typeof colors !== "object") return []
  var out = []
  for (var i = 0; i < SWATCH_KEYS.length; i++) {
    var value = colors[SWATCH_KEYS[i]]
    if (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value))
      out.push({ key: SWATCH_KEYS[i], color: value })
  }
  return out
}

function archiveEntries(archive) {
  return archive && Array.isArray(archive.entries) ? archive.entries : []
}

function findEntry(archive, id) {
  var entries = archiveEntries(archive)
  for (var i = 0; i < entries.length; i++) {
    if (entries[i] && entries[i].id === id) return entries[i]
  }
  return null
}

// The entry describing what is on screen now, built from state.json so the
// hero still works before the archive has been written.
function currentEntry(state) {
  if (!state || !state.imageId) return null
  return {
    id: state.imageId, date: state.date || "", title: state.title || "",
    copyright: state.copyright || "", link: safeLink(state.link), image: state.image || "",
    market: state.market || "", colors: null
  }
}

// Third status line: the archive while it is still coming down.
function archiveLine(state, archive) {
  if (!state) return ""
  var status = String(state.archive || "")
  if (status === "downloading") {
    var progress = state.archiveProgress ? " (" + state.archiveProgress + ")" : ""
    return "Downloading this week's pictures" + progress + "…"
  }
  if (status === "partial") return "Some of this week's pictures could not be downloaded"
  return ""
}

function nextCheckText(state) {
  if (!state || !state.nextCheck) return ""
  var when = new Date(Number(state.nextCheck) * 1000)
  if (isNaN(when.getTime())) return ""
  return "Next check " + Qt.formatTime(when, "HH:mm")
}
