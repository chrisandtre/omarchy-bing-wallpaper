// Bing -- the image of the day on the lock screen, the way Windows shows it:
// the picture sharp and full screen, a large clock over it, and the story
// behind it in the corner.
//
// Installed into ~/.config/omarchy/lock-designs/ by the Bing Wallpaper & Theme
// plugin (io.github.chrisandtre.bing-wallpaper) when its "Lock screen" setting
// is on, and selected in Lock Screen Explorer as "my-bing". The plugin
// refreshes this copy on upgrade only while it is unchanged; edit it and it is
// yours. Turning the setting off removes it (again, only if unchanged).
//
// The picture itself is whatever Omarchy's current background is, which the
// plugin points at Bing's image every morning, so a new day's picture reaches
// the lock screen with nothing else to do. The caption is read from the
// plugin's state file and shown only while that file describes the picture
// actually on screen -- pick another wallpaper and the caption steps aside.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import "../plugins/io.github.sirjul1337.lock-explorer/designs"

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int pad: Math.round(Math.min(width, height) * 0.05)
  readonly property color ink: "#ffffff"

  // ---- The picture's story, from bing-wallpaper's state.json
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  property var bing: ({})
  readonly property bool captionMatches: !!bing.image && String(bing.image) === String(lock.backgroundPath)
  readonly property string title: captionMatches && bing.title ? String(bing.title) : ""
  // "Place, Country (© Photographer/Agency)" -> place and credit.
  readonly property var credit: {
    var c = captionMatches && bing.copyright ? String(bing.copyright) : ""
    var m = c.match(/^(.*?)\s*\((©[^)]*)\)\s*$/)
    return m ? { place: m[1], by: m[2] } : { place: c, by: "" }
  }

  FileView {
    id: stateFile
    path: lock.stateHome + "/bing-wallpaper/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { lock.bing = JSON.parse(text()) || {} } catch (e) { lock.bing = {} }
    }
    onLoadFailed: lock.bing = {}
  }

  // ---- Picture: sharp, with just enough shade top and bottom for the text
  Wallpaper {
    anchors.fill: parent
    lock: lock
    blur: 0.0
    dim: 0.04
    vignetteTop: 0.30
    vignetteMiddle: 0.0
    vignetteBottom: 0.50
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // White text over a photograph needs a soft shadow, whatever the picture.
  component Shadowed: MultiEffect {
    shadowEnabled: true
    shadowColor: "#000000"
    shadowOpacity: 0.55
    shadowBlur: 0.6
    shadowVerticalOffset: 2
    shadowHorizontalOffset: 0
  }

  // ---- Clock
  Column {
    id: clock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Math.round(lock.height * 0.11)
    spacing: 4
    opacity: lock.snapshotMode ? 0 : 1
    visible: false

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("H:mm")
      color: lock.ink
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.Medium
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.date("dddd, MMMM d")
      color: lock.ink
      font.family: Style.font.family
      font.pixelSize: Style.font.display
    }
  }
  Shadowed { source: clock; anchors.fill: clock; opacity: clock.opacity }

  // ---- Caption, bottom left
  Column {
    id: caption
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.leftMargin: lock.pad
    anchors.bottomMargin: lock.pad
    width: Math.min(Math.round(lock.width * 0.32), 560)
    spacing: 4
    visible: false

    Text {
      width: parent.width
      visible: lock.title !== ""
      text: lock.title
      textFormat: Text.PlainText
      color: lock.ink
      font.family: Style.font.family
      font.pixelSize: Style.font.display
      font.weight: Font.DemiBold
      wrapMode: Text.WordWrap
    }
    Text {
      width: parent.width
      visible: text !== ""
      text: lock.credit.place
      textFormat: Text.PlainText
      color: lock.withAlpha(lock.ink, 0.88)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      wrapMode: Text.WordWrap
    }
    Text {
      width: parent.width
      visible: text !== ""
      text: lock.credit.by
      textFormat: Text.PlainText
      color: lock.withAlpha(lock.ink, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      wrapMode: Text.WordWrap
    }
  }
  Shadowed { source: caption; anchors.fill: caption; visible: lock.title !== "" || lock.credit.place !== "" }

  // ---- Sign in, bottom centre
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.12)
    spacing: 12

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 340
      height: 46
      radius: 23
      outlineThickness: 1
      showLockGlyph: false
      placeholder: lock.tr("Password")
      color: lock.withAlpha("#000000", 0.35)
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: lock.errorState
      text: lock.failureMessage
      textFormat: Text.PlainText
      color: Commons.Color.lock.textError
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
    }
  }
}
