import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar pill for the Bing image of the day: an image glyph plus today's title.
// Left click opens the detail panel, middle click forces a refresh, right
// click opens the story behind the picture in the browser.
BarWidget {
  id: root
  moduleName: Model.PLUGIN_ID

  // Parsed ~/.local/state/bing-wallpaper/state.json, written by bin/bing-wallpaper.
  property var state: ({})
  // Parsed archive.json: this week's pictures with the palette each would give.
  property var archive: ({})

  readonly property string script: String(Qt.resolvedUrl("bin/bing-wallpaper")).replace(/^file:\/\//, "")

  readonly property bool showTitle: setting("showTitle", true)
  readonly property int maxTitleChars: Number(setting("maxTitleChars", 28))
  readonly property string stateHome: {
    var xdg = Quickshell.env("XDG_STATE_HOME")
    return xdg && xdg !== "" ? xdg : Quickshell.env("HOME") + "/.local/state"
  }
  readonly property string displayText: Model.barLabel(state, showTitle && !vertical, maxTitleChars)
  readonly property string tooltip: state && state.copyright ? String(state.copyright) : "Bing image of the day"

  function service() {
    return bar && bar.shell && typeof bar.shell.serviceFor === "function"
      ? bar.shell.serviceFor(moduleName) : null
  }

  readonly property bool busy: {
    var s = service()
    return s ? s.busy === true : false
  }

  function refresh() {
    var s = service()
    if (s && typeof s.fetch === "function") s.fetch(true)
    else Util.execArgv(["bash", root.script, "fetch", "--force"])
  }

  // Switch to an archived picture (a date, an archive id, or N days ago).
  function applyArchive(when) {
    if (when === undefined || when === null || String(when) === "") return
    var s = service()
    if (s && typeof s.apply === "function") s.apply(String(when))
    else Util.execArgv(["bash", root.script, "apply", String(when)])
  }

  function openLink(link) {
    if (!link) return
    Util.execArgv(["omarchy-launch-browser", String(link)])
  }

  function openStory() {
    if (state && state.link) openLink(state.link)
  }

  // Persist one setting onto this widget's inline shell.json entry, the way
  // the clock stores its format. The service picks the new value up from
  // shell.json on its next fetch, which the panel triggers right away.
  function updateSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    refetchAfterSettings.restart()
  }

  Timer {
    id: refetchAfterSettings
    interval: 600
    repeat: false
    onTriggered: {
      var s = root.service()
      if (s && typeof s.fetch === "function") s.fetch(false)
    }
  }

  FileView {
    id: stateFile
    path: root.stateHome + "/bing-wallpaper/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.state = Model.parseState(text())
    onLoadFailed: root.state = ({})
  }

  FileView {
    id: archiveFile
    path: root.stateHome + "/bing-wallpaper/archive.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.archive = Model.parseState(text())
    onLoadFailed: root.archive = ({})
  }

  // ---- Detail panel plumbing (same shape contract as omarchy.weather so
  //      shell summon/hide/toggle and the bar's popout coordinator work).
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property real openPanelIndicatorWidth: button.labelWidth

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    tooltipText: root.opened ? "" : root.tooltip
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.RightButton) root.openStory()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
