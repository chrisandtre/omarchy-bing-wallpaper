import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Detail popup under the bar pill: a preview of today's picture, its title
// and credit, quick actions, and the plugin's settings.
Panel {
  id: root
  moduleName: Model.PLUGIN_ID
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false

  // The bar identifies this popup by the widget mounted in its slot, not by
  // this nested panel (see omarchy.weather for the same arrangement).
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var state: hostWidget && hostWidget.state ? hostWidget.state : ({})
  readonly property bool busy: hostWidget ? hostWidget.busy === true : false
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var credit: Model.splitCopyright(state.copyright)

  readonly property string market: String(setting("market", "en-US"))
  readonly property string mode: String(setting("mode", "dark"))
  readonly property string extractMode: String(setting("extractMode", "normal"))
  readonly property bool applyTheme: setting("applyTheme", true) !== false && setting("applyTheme", true) !== "false"
  readonly property bool screensaver: setting("screensaver", true) !== false && setting("screensaver", true) !== "false"
  readonly property string screensaverSize: String(setting("screensaverSize", "120x29"))

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function update(key, value) {
    if (hostWidget && typeof hostWidget.updateSetting === "function") hostWidget.updateSetting(key, value)
  }

  function refresh() {
    if (hostWidget && typeof hostWidget.refresh === "function") hostWidget.refresh()
  }

  function openStory() {
    if (hostWidget && typeof hostWidget.openStory === "function") hostWidget.openStory()
  }

  function openFolder() {
    if (bar) bar.run("xdg-open " + bar.shellQuote(Quickshell.env("HOME") + "/.config/omarchy/themes/bing/backgrounds"))
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(820))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onReturnRequested: root.openStory()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroll.width
          spacing: Style.space(12)

          // ---- Picture
          Rectangle {
            width: parent.width
            height: Math.round(width * 9 / 16)
            radius: Math.min(Style.space(8), Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(8))
            color: Util.alpha(root.foreground, 0.06)
            clip: true

            Image {
              anchors.fill: parent
              source: root.state.image ? "file://" + root.state.image : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize.width: 960
              smooth: true
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: !root.state.image
              text: Model.ICON
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
            }

            // Hover-to-open affordance.
            HoverHandler { id: pictureHover; cursorShape: root.state.link ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: root.openStory() }

            Rectangle {
              anchors.fill: parent
              color: Util.alpha(root.foreground, pictureHover.hovered ? 0.06 : 0)
              Behavior on color { ColorAnimation { duration: 120 } }
            }
          }

          // ---- Title, place, credit
          Column {
            width: parent.width
            spacing: Style.space(4)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.state.title || "Bing image of the day"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              visible: root.credit.place !== ""
              textFormat: Text.PlainText
              text: root.credit.place
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              visible: root.credit.credit !== ""
              textFormat: Text.PlainText
              text: root.credit.credit
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: [
                Model.prettyDate(root.state.date),
                Model.optionLabel(Model.MARKETS, root.state.market, root.state.market),
                root.state.mode ? (String(root.state.mode).charAt(0).toUpperCase() + String(root.state.mode).slice(1) + " palette") : ""
              ].filter(function(s) { return s && s !== "" }).join("  ·  ")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 0.5
              wrapMode: Text.WordWrap
            }
          }

          // ---- Actions
          Row {
            spacing: Style.space(8)

            Button {
              iconText: "󰑐"
              iconSpinning: root.busy
              text: root.busy ? "Refreshing…" : "Refresh"
              enabled: !root.busy
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              tooltipText: "Fetch today's image again and rebuild the theme"
              onClicked: root.refresh()
            }

            Button {
              iconText: "󰖟"
              text: "Open story"
              enabled: !!root.state.link
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              tooltipText: "Read about today's picture on Bing"
              onClicked: root.openStory()
            }

            Button {
              iconText: "󰉏"
              text: "Wallpapers"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              tooltipText: "Open the folder holding this week's images"
              onClicked: root.openFolder()
            }
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          // ---- Settings
          PanelSectionHeader {
            text: "SETTINGS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Toggle {
            width: parent.width
            label: "Re-theme with Aether"
            description: "Rebuild the Bing theme from each day's picture"
            checked: root.applyTheme
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.update("applyTheme", !root.applyTheme)
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            Dropdown {
              width: (parent.width - parent.spacing) / 2
              label: "Region"
              value: root.market
              options: Model.MARKETS
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(v) { if (v !== root.market) root.update("market", v) }
            }

            Dropdown {
              width: (parent.width - parent.spacing) / 2
              label: "Palette mode"
              value: root.mode
              options: Model.MODES
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(v) { if (v !== root.mode) root.update("mode", v) }
            }
          }

          Dropdown {
            width: parent.width
            label: "Palette style"
            value: root.extractMode
            options: Model.EXTRACT_MODES
            enabled: root.applyTheme
            opacity: root.applyTheme ? 1 : 0.5
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function(v) { if (v !== root.extractMode) root.update("extractMode", v) }
          }

          Toggle {
            width: parent.width
            label: "Use as screensaver"
            description: root.state.screensaver === "magick-missing"
              ? "Needs ImageMagick — run: bing-wallpaper install-deps"
              : "Draw today's picture as the Omarchy screensaver art"
            checked: root.screensaver
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.update("screensaver", !root.screensaver)
          }

          Dropdown {
            width: parent.width
            label: "Screensaver size"
            value: root.screensaverSize
            options: Model.SCREENSAVER_SIZES
            enabled: root.screensaver
            opacity: root.screensaver ? 1 : 0.5
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function(v) { if (v !== root.screensaverSize) root.update("screensaverSize", v) }
          }

          // ---- Status
          Column {
            width: parent.width
            spacing: Style.space(2)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.busy ? "Fetching today's image…" : Model.statusLine(root.state)
              color: root.state.status === "error" ? (root.bar ? root.bar.urgent : Color.urgent) : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              visible: text !== ""
              textFormat: Text.PlainText
              text: Model.screensaverLine(root.state)
              color: root.state.screensaver === "magick-missing" || root.state.screensaver === "failed"
                ? (root.bar ? root.bar.urgent : Color.urgent) : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              visible: text !== ""
              textFormat: Text.PlainText
              text: Model.nextCheckText(root.state)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
