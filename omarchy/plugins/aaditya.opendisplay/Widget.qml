import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Shown while OpenDisplay (daemon or app) is running.
// Click: connect, or when streaming, disconnect and quit OpenDisplay entirely.
// Right click while streaming: switch extend/mirror.
BarWidget {
  id: root
  moduleName: "aaditya.opendisplay"

  property bool running: false
  property var state: ({})
  readonly property bool streaming: state.active === true

  visible: running
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function load(text) {
    var out = String(text || "").trim()
    running = out !== ""
    try { state = out.startsWith("{") ? (JSON.parse(out).state || ({})) : ({}) } catch (e) { state = ({}) }
  }

  Process {
    id: statusProc
    // Only ask the daemon when it is up: `opendisplayctl status` would start it again.
    command: ["bash", "-c",
      "if pgrep -x opendisplayd >/dev/null; then opendisplayctl status --json; " +
      "elif pgrep -x opendisplay-gui >/dev/null; then echo gui; fi"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.load(text)
    }
  }

  // shortcut: polls every 2s, switch to `opendisplayctl watch --json` if this feels laggy
  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: String.fromCodePoint(root.streaming ? 0xF04F6 : 0xF04F7)
    active: root.streaming
    tooltipText: root.streaming
      ? (root.state.mode === "mirror" ? "Mirroring" : "Extending") + " to " + (root.state.device || "iPad") +
        " over " + (root.state.transport || "?") + "\nClick: disconnect and quit · Right click: switch mode"
      : "OpenDisplay not connected\nClick: connect"
    onPressed: function(b) {
      if (root.streaming && b === Qt.RightButton) root.bar.run("opendisplayctl toggle-mode")
      else if (root.streaming) root.bar.run("opendisplayctl disconnect; systemctl --user stop opendisplayd; pkill -x opendisplay-gui")
      else if (b !== Qt.RightButton) root.bar.run("opendisplayctl connect")
      statusProc.running = true
    }
  }
}
