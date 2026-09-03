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

function nextCheckText(state) {
  if (!state || !state.nextCheck) return ""
  var when = new Date(Number(state.nextCheck) * 1000)
  if (isNaN(when.getTime())) return ""
  return "Next check " + Qt.formatTime(when, "HH:mm")
}
