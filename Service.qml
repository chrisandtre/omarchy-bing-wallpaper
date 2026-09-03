import QtQuick
import Quickshell
import Quickshell.Io

// Headless half of the plugin: keeps today's Bing image (and the generated
// "Bing" theme) current by running bin/bing-wallpaper on a schedule. The
// script is idempotent and cheap when nothing changed, so ticking every
// fifteen minutes costs nothing and survives suspend/resume and offline
// stretches without any extra bookkeeping.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null

  readonly property string script: String(Qt.resolvedUrl("bin/bing-wallpaper")).replace(/^file:\/\//, "")
  readonly property bool busy: fetchProcess.running

  property string lastOutput: ""
  property int lastExitCode: 0
  property bool pendingForce: false
  property bool pendingFetch: false

  function fetch(force) {
    if (fetchProcess.running) {
      pendingFetch = true
      if (force) pendingForce = true
      return
    }
    var args = ["bash", script, "fetch"]
    if (force) args.push("--force")
    fetchProcess.command = args
    fetchProcess.running = true
  }

  function openStory() {
    Quickshell.execDetached(["bash", script, "open"])
  }

  Process {
    id: fetchProcess
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lastOutput = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.lastExitCode = exitCode
      if (exitCode !== 0 && root.lastOutput !== "")
        console.warn("bing-wallpaper: " + root.lastOutput)
      if (root.pendingFetch) {
        var force = root.pendingForce
        root.pendingFetch = false
        root.pendingForce = false
        Qt.callLater(function() { root.fetch(force) })
      }
    }
  }

  // Let the shell finish coming up before the first run; theme application
  // restarts terminals and re-tints apps, which is rude mid-login.
  Timer {
    interval: 8000
    running: true
    repeat: false
    onTriggered: root.fetch(false)
  }

  Timer {
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.fetch(false)
  }

  // omarchy-shell io.github.chrisandtre.bing-wallpaper fetch | refresh | open
  IpcHandler {
    target: "io.github.chrisandtre.bing-wallpaper"

    function fetch(): void { root.fetch(false) }
    function refresh(): void { root.fetch(true) }
    function open(): void { root.openStory() }
  }
}
