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

  // The execution boundary lives in Exec.qml: absolute interpreter, explicit
  // environment, and `timeout` owning the process group so a job's children
  // cannot outlive it. Read that file for the why.
  readonly property Exec exec: Exec {}

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
    process.command = exec.command(script, exec.jobDeadline, args)
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

  // `bing-wallpaper open [when]` re-checks the link against the bing.com
  // allowlist before it reaches a browser, so the panel never has to.
  function openStory(when) {
    exec.detached(script, exec.actionDeadline,
                  when === undefined || when === null || String(when) === "" ? ["open"] : ["open", String(when)])
  }

  // The panel's Wallpapers button. Only ever the plugin's own folder.
  function openBackgrounds() {
    exec.detached(script, exec.actionDeadline, ["backgrounds"])
  }

  Process {
    id: process
    clearEnvironment: true
    environment: root.exec.environment
    stderr: StdioCollector {
      waitForEnd: true
      // The script caps its own stderr well below this; the guard is here so a
      // helper that somehow writes past it still cannot grow this buffer.
      onStreamFinished: root.lastOutput = String(text || "").trim().slice(0, 8192)
    }
    onExited: function(exitCode) {
      root.lastExitCode = exitCode
      // 124 is timeout(1) reporting that the deadline was reached; 137 is the
      // KILL that follows when the job ignored the TERM.
      if (exitCode === 124 || exitCode === 137)
        console.warn("bing-wallpaper: job exceeded its " + root.exec.jobDeadline + "s deadline and was terminated")
      else if (exitCode !== 0 && root.lastOutput !== "")
        console.warn("bing-wallpaper: " + root.lastOutput)
      if (root.pending !== null) {
        var next = root.pending
        root.pending = null
        Qt.callLater(function() { root.run(next) })
      }
    }
  }

  // Drifts the screensaver's camera between ttfx effects; see
  // `bing-wallpaper parallax`. The script blocks on Hyprland's event socket
  // until a screensaver window opens, so keeping it alive costs nothing. If it
  // ever dies it is brought back after a pause. No deadline -- it is meant to
  // run for the session -- but it goes through `timeout` all the same, for the
  // process group that makes shutdown reach its children.
  Process {
    id: parallax
    clearEnvironment: true
    environment: root.exec.environment
    command: root.exec.command(root.script, 0, ["parallax"])
    running: true
    onExited: parallaxRestart.restart()
  }

  Timer {
    id: parallaxRestart
    interval: 30000
    repeat: false
    onTriggered: parallax.running = true
  }

  // Going away is not a reason to leave a download or a theme build running.
  // TERM reaches the whole process group through `timeout`, which escalates to
  // KILL on its own after --kill-after if anything in there ignores it.
  Component.onDestruction: {
    parallaxRestart.stop()
    if (parallax.running) parallax.signal(15)
    if (process.running) process.signal(15)
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
    function open(): void { root.openStory("") }
    function apply(when: string): void { root.apply(when) }
  }
}
