import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Detail popup under the bar pill: a preview of the picture, its title and
// credit, the palette Aether builds from it, this week's other pictures
// (click one to preview what the theme would become, then apply it), quick
// actions, and the plugin's settings.
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
  readonly property var archive: hostWidget && hostWidget.archive ? hostWidget.archive : ({})
  readonly property var entries: Model.archiveEntries(archive)
  readonly property bool busy: hostWidget ? hostWidget.busy === true : false
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // What is on screen, and what the user is looking at. Clicking an archive
  // card previews it in the hero without changing anything; "Use this
  // picture" commits.
  readonly property string currentId: state.imageId ? String(state.imageId) : ""
  property string previewId: ""
  readonly property var previewEntry: previewId !== "" ? Model.findEntry(archive, previewId) : null
  readonly property var shown: previewEntry || Model.findEntry(archive, currentId) || Model.currentEntry(state) || ({})
  readonly property bool previewing: previewEntry !== null && previewEntry.id !== currentId
  readonly property var swatches: Model.swatches(shown.colors)
  readonly property var credit: Model.splitCopyright(shown.copyright)

  onCurrentIdChanged: previewId = ""

  readonly property string market: String(setting("market", "en-US"))
  readonly property string mode: String(setting("mode", "dark"))
  readonly property string extractMode: String(setting("extractMode", "normal"))
  readonly property bool applyTheme: setting("applyTheme", true) !== false && setting("applyTheme", true) !== "false"
  readonly property bool screensaver: setting("screensaver", true) !== false && setting("screensaver", true) !== "false"
  readonly property string screensaverSize: String(setting("screensaverSize", "120x29"))
  readonly property string screensaverStyle: String(setting("screensaverStyle", "auto"))
  readonly property bool screensaverCaption: setting("screensaverCaption", true) !== false && setting("screensaverCaption", true) !== "false"
  readonly property bool screensaverParallax: setting("screensaverParallax", true) !== false && setting("screensaverParallax", true) !== "false"
  // Parallax only means something for the depth style ("auto" is depth
  // wherever colour works).
  readonly property bool parallaxApplies: screensaverStyle === "auto" || screensaverStyle === "depth"

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

  // Opens the story behind whichever picture the hero is showing.
  function openStory() {
    if (!shown.link) return
    if (hostWidget && typeof hostWidget.openLink === "function") hostWidget.openLink(shown.link)
    else Util.execArgv(["omarchy-launch-browser", String(shown.link)])
  }

  function applyPreview() {
    if (!previewing || !previewEntry.date) return
    if (hostWidget && typeof hostWidget.applyArchive === "function") hostWidget.applyArchive(previewEntry.date)
  }

  function togglePreview(id) {
    previewId = (previewId === id || id === currentId) ? "" : id
  }

  function openFolder() {
    var config = Quickshell.env("XDG_CONFIG_HOME")
    if (!config || config === "") config = Quickshell.env("HOME") + "/.config"
    Util.execArgv(["xdg-open", config + "/omarchy/themes/bing/backgrounds"])
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(1500))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.previewing) root.previewId = ""
        else root.close()
      }
      onReturnRequested: {
        if (root.previewing) root.applyPreview()
        else root.openStory()
      }
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
              source: root.shown.image ? Util.fileUrl(root.shown.image) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize.width: 960
              smooth: true
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: !root.shown.image
              text: Model.ICON
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
            }

            // "Preview" ribbon while looking at a picture that is not applied.
            Rectangle {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.margins: Style.space(8)
              visible: root.previewing
              radius: Style.space(4)
              color: Util.alpha("#000000", 0.55)
              implicitWidth: previewLabel.implicitWidth + Style.space(12)
              implicitHeight: previewLabel.implicitHeight + Style.space(6)

              Text {
                id: previewLabel
                anchors.centerIn: parent
                text: "PREVIEW"
                color: "#ffffff"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }
            }

            // Hover-to-open affordance.
            HoverHandler { id: pictureHover; cursorShape: root.shown.link ? Qt.PointingHandCursor : Qt.ArrowCursor }
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
              text: root.shown.title || "Bing image of the day"
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
                Model.prettyDate(root.shown.date),
                Model.optionLabel(Model.MARKETS, root.shown.market || root.state.market, root.shown.market || root.state.market),
                root.state.mode ? (String(root.state.mode).charAt(0).toUpperCase() + String(root.state.mode).slice(1) + " palette") : ""
              ].filter(function(s) { return s && s !== "" }).join("  ·  ")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 0.5
              wrapMode: Text.WordWrap
            }
          }

          // ---- Palette: what the theme looks like for the shown picture
          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: root.swatches.length > 0 || !!root.shown.image

            Row {
              id: swatchRow
              width: parent.width
              spacing: Style.space(4)
              visible: root.swatches.length > 0

              readonly property real chipWidth: root.swatches.length > 0
                ? (width - spacing * (root.swatches.length - 1)) / root.swatches.length : 0

              Repeater {
                model: root.swatches

                Rectangle {
                  required property var modelData
                  width: swatchRow.chipWidth
                  height: Style.space(30)
                  radius: Style.space(4)
                  color: modelData.color
                  border.width: 1
                  border.color: Util.alpha(root.foreground, 0.18)

                  // The background chip carries "Aa" in the foreground colour
                  // so text contrast is visible at a glance.
                  Text {
                    anchors.centerIn: parent
                    visible: parent.modelData.key === "background"
                    text: "Aa"
                    color: root.shown.colors && root.shown.colors.foreground ? root.shown.colors.foreground : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  HoverHandler { id: chipHover }
                  PanelToolTip {
                    visible: chipHover.hovered
                    text: parent.modelData.key + "  " + parent.modelData.color
                  }
                }
              }
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.swatches.length > 0
                ? (root.previewing ? "Palette this picture would give the Bing theme" : "Palette of the current Bing theme")
                : (root.state.theme === "aether-missing" ? "Install Aether to preview palettes" : "Palette preview not ready yet")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ---- Actions
          Flow {
            width: parent.width
            spacing: Style.space(8)

            Button {
              visible: root.previewing
              iconText: "󰄬"
              text: "Use this picture"
              enabled: !root.busy
              foreground: root.foreground
              accent: root.accent
              selected: true
              fontFamily: root.fontFamily
              bordered: true
              tooltipText: "Set this picture as the wallpaper and rebuild the theme from it"
              onClicked: root.applyPreview()
            }

            Button {
              visible: !root.previewing
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
              enabled: !!root.shown.link
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              tooltipText: "Read about this picture on Bing"
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

          // ---- This week
          PanelSectionHeader {
            text: "THIS WEEK"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.entries.length > 0
              ? "Click a picture to preview its palette; the highlighted one is on screen now."
              : (root.busy || root.state.archive === "downloading"
                ? "Fetching this week's pictures…"
                : "This week's pictures appear here after the first fetch.")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Grid {
            id: archiveGrid
            width: parent.width
            columns: 4
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(8)
            visible: root.entries.length > 0

            readonly property real cardWidth: (width - columnSpacing * (columns - 1)) / columns
            readonly property real swatchHeight: Style.space(6)
            readonly property real cardHeight: Math.round(cardWidth * 9 / 16) + swatchHeight

            Repeater {
              model: root.entries

              Item {
                id: card
                required property var modelData
                readonly property var entry: modelData || ({})
                readonly property bool isCurrent: entry.id === root.currentId
                readonly property bool isPreview: entry.id === root.previewId && !isCurrent
                readonly property var cardSwatches: Model.swatches(entry.colors)
                width: archiveGrid.cardWidth
                height: archiveGrid.cardHeight

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(6)
                  color: Util.alpha(root.foreground, cardHover.hovered ? 0.12 : 0.06)
                  border.width: card.isCurrent || card.isPreview ? 2 : 0
                  border.color: card.isCurrent ? root.accent : root.foreground
                  clip: true
                  Behavior on color { ColorAnimation { duration: 120 } }

                  Image {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 2
                    height: parent.height - archiveGrid.swatchHeight - 2
                    source: card.entry.image ? Util.fileUrl(card.entry.image) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 240
                    smooth: true
                    visible: status === Image.Ready
                  }

                  Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -archiveGrid.swatchHeight / 2
                    visible: !card.entry.image
                    text: "󰇚"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.icon
                  }

                  // Day label.
                  Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: Style.space(4)
                    radius: Style.space(3)
                    color: Util.alpha("#000000", 0.55)
                    implicitWidth: dayText.implicitWidth + Style.space(8)
                    implicitHeight: dayText.implicitHeight + Style.space(4)

                    Text {
                      id: dayText
                      anchors.centerIn: parent
                      text: Model.dayLabel(card.entry.date)
                      color: "#ffffff"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // The picture's palette, as a thin strip along the bottom.
                  Row {
                    id: strip
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    height: archiveGrid.swatchHeight - 2

                    Repeater {
                      model: card.cardSwatches
                      Rectangle {
                        required property var modelData
                        width: card.cardSwatches.length > 0 ? strip.width / card.cardSwatches.length : 0
                        height: strip.height
                        color: modelData.color
                      }
                    }
                  }
                }

                HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.togglePreview(card.entry.id) }

                PanelToolTip {
                  visible: cardHover.hovered && !!card.entry.title
                  text: (card.entry.title || "") + (card.isCurrent ? "  ·  on screen now" : "")
                }
              }
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

          Row {
            width: parent.width
            spacing: Style.space(10)

            Dropdown {
              width: (parent.width - parent.spacing) / 2
              label: "Screensaver style"
              value: root.screensaverStyle
              options: Model.SCREENSAVER_STYLES
              enabled: root.screensaver
              opacity: root.screensaver ? 1 : 0.5
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(v) { if (v !== root.screensaverStyle) root.update("screensaverStyle", v) }
            }

            Dropdown {
              width: (parent.width - parent.spacing) / 2
              label: "Screensaver size"
              value: root.screensaverSize
              options: Model.SCREENSAVER_SIZES
              enabled: root.screensaver
              opacity: root.screensaver ? 1 : 0.5
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(v) { if (v !== root.screensaverSize) root.update("screensaverSize", v) }
            }
          }

          Toggle {
            width: parent.width
            label: "Caption"
            description: "Name the picture and its place under the art"
            checked: root.screensaverCaption
            enabled: root.screensaver
            opacity: root.screensaver ? 1 : 0.5
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.update("screensaverCaption", !root.screensaverCaption)
          }

          Toggle {
            width: parent.width
            label: "Parallax drift"
            description: "Shift the scene by depth between effects, so the camera seems to move"
            checked: root.screensaverParallax
            enabled: root.screensaver && root.parallaxApplies
            opacity: root.screensaver && root.parallaxApplies ? 1 : 0.5
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.update("screensaverParallax", !root.screensaverParallax)
          }

          // ---- Status
          Column {
            width: parent.width
            spacing: Style.space(2)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.busy && root.state.archive !== "downloading" ? "Fetching today's image…" : Model.statusLine(root.state)
              color: root.state.status === "error" ? (root.bar ? root.bar.urgent : Color.urgent) : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              visible: text !== ""
              textFormat: Text.PlainText
              text: Model.archiveLine(root.state, root.archive)
              color: root.dim
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
