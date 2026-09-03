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
  readonly property bool busy: process.running

  property string lastOutput: ""
  property int lastExitCode: 0

  // One script invocation at a time. Anything asked for while it runs is
  // queued and started when it exits; a forced fetch is never downgraded by a
  // plain one that arrives after it.
  property var pending: null

  function run(args) {
    if (process.running) {
      var plainFetch = args.length === 1 && args[0] === "fetch"
      if (!(plainFetch && root.pending !== null)) root.pending = args
      return
    }
    process.command = ["bash", script].concat(args)
    process.running = true
  }

  function fetch(force) {
    run(force ? ["fetch", "--force"] : ["fetch"])
  }

  // Switch to an archived picture: a date (YYYY-MM-DD), an archive id, or
  // N days ago. The theme follows, exactly as for the daily change.
  function apply(when) {
    if (when === undefined || when === null || String(when) === "") return
    run(["apply", String(when)])
  }

  function openStory() {
    Quickshell.execDetached(["bash", script, "open"])
  }

  Process {
    id: process
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lastOutput = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.lastExitCode = exitCode
      if (exitCode !== 0 && root.lastOutput !== "")
        console.warn("bing-wallpaper: " + root.lastOutput)
      if (root.pending !== null) {
        var next = root.pending
        root.pending = null
        Qt.callLater(function() { root.run(next) })
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

  // omarchy-shell io.github.chrisandtre.bing-wallpaper fetch | refresh | open | apply <when>
  IpcHandler {
    target: "io.github.chrisandtre.bing-wallpaper"

    function fetch(): void { root.fetch(false) }
    function refresh(): void { root.fetch(true) }
    function open(): void { root.openStory() }
    function apply(when: string): void { root.apply(when) }
  }
}
