import QtQuick
import Quickshell

// The plugin's execution boundary, in one place so there is one thing to
// audit. Everything this plugin runs -- the service's scheduled refresh, the
// bar widget's fallbacks when the service is not mounted, the panel's story
// and folder actions -- goes through here.
//
// Three things it guarantees:
//
//   * The interpreter is addressed by absolute path, and the script is handed
//     an explicit environment instead of whatever omarchy-shell inherited. An
//     unattended refresh runs every fifteen minutes, so a writable directory
//     early on somebody's PATH must not get to decide what "bash" means. (The
//     script pins PATH again on its own side; see bin/bing-wallpaper.)
//
//   * `timeout` owns the job. It puts the command in its own process group, so
//     the deadline and the TERM-then-KILL escalation reach everything the
//     script spawned -- curl, ImageMagick, Aether, socat -- rather than
//     orphaning them when the shell that started them goes away. A duration of
//     0 disables the deadline for the parallax daemon, which is long-lived by
//     design but still wants the group.
//
//   * Every action is a subcommand of bin/bing-wallpaper. Nothing here launches
//     a browser or a file manager directly, so remote strings meet exactly one
//     sanitizer (`sanitize_link`) on exactly one path.
QtObject {
  id: root

  readonly property string bashBin: "/usr/bin/bash"
  readonly property string timeoutBin: "/usr/bin/timeout"
  readonly property string trustedPath: "/usr/bin:/bin:/usr/share/omarchy/bin:/usr/local/bin"
  readonly property string killAfter: "10s"

  // A fetch that downloads a week of pictures and rebuilds the theme is the
  // slow case; past this the job is wedged, not working.
  readonly property int jobDeadline: 300
  // Handing a link or a folder to the session's handler is instant.
  readonly property int actionDeadline: 60

  function envOr(name, fallback) {
    var value = Quickshell.env(name)
    return value === undefined || value === null || String(value) === "" ? fallback : String(value)
  }

  // Explicit allowlist. HOME and OMARCHY_PATH are read directly by the script
  // and by omarchy-theme-set; the rest is the minimum the theme, browser and
  // notification helpers need to reach the running session.
  readonly property var environment: {
    var env = {
      "PATH": root.trustedPath,
      "HOME": root.envOr("HOME", ""),
      "OMARCHY_PATH": root.envOr("OMARCHY_PATH", "/usr/share/omarchy")
    }
    var passthrough = ["USER", "LANG", "XDG_CONFIG_HOME", "XDG_STATE_HOME",
                       "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR",
                       "XDG_CURRENT_DESKTOP", "WAYLAND_DISPLAY",
                       "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS"]
    for (var i = 0; i < passthrough.length; i++) {
      var value = root.envOr(passthrough[i], "")
      if (value !== "") env[passthrough[i]] = value
    }
    return env
  }

  // `timeout --kill-after=10s <seconds> /usr/bin/bash <script> <args...>`
  function command(script, seconds, args) {
    return [root.timeoutBin, "--kill-after=" + root.killAfter, String(seconds),
            root.bashBin, String(script)].concat(args || [])
  }

  // Fire-and-forget: the action outlives this shell instance on purpose (a
  // browser tab should not close because the bar reloaded).
  function detached(script, seconds, args) {
    Quickshell.execDetached({
      command: root.command(script, seconds, args),
      environment: root.environment,
      clearEnvironment: true
    })
  }
}
