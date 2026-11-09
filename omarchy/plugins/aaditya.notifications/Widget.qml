import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Notification center for the bar. The stock omarchy.notifications service
// exposes no history API to plugins, but it keeps every notification as a
// one-line JSON file on disk, so this reads (and removes) those files.
BarWidget {
  id: root
  moduleName: "aaditya.notifications"

  readonly property string iconBell: String.fromCodePoint(0xF009A)
  readonly property string iconBellOff: String.fromCodePoint(0xF009B)
  readonly property string iconClose: String.fromCodePoint(0xF0156)
  readonly property string iconClearAll: String.fromCodePoint(0xF01B4)

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/"
  readonly property string settingsPath: stateDir + "notifications.json"
  // Toasts still on screen live here; once they leave they move to history/.
  readonly property string popupDir: stateDir + "notifications/"
  readonly property string historyDir: popupDir + "history/"
  readonly property string imagesDir: popupDir + "images/"
  readonly property string seenPath: stateDir + "aaditya.notifications.seen"

  readonly property int pollSeconds: Math.max(1, Number(setting("pollSeconds", 3)) || 3)
  readonly property bool showCount: setting("showCount", true) !== false

  readonly property var notificationService: bar && bar.shell && bar.shell.firstPartyServiceFor
    ? bar.shell.firstPartyServiceFor("omarchy.notifications") : null
  property bool fileDnd: false
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : fileDnd

  property var entries: []
  // Stems removed in the UI, hidden until the files are really gone.
  property var hidden: ({})
  property real now: Date.now()
  property real lastSeen: 0
  property bool seenLoaded: false
  readonly property int unread: {
    var count = 0
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].timestamp > lastSeen) count++
    }
    return count
  }

  property bool popupOpen: false

  function close() { popupOpen = false }

  onPopupOpenChanged: {
    markSeen()
    if (popupOpen) refresh()
  }

  function refresh() {
    if (readProc.running) return
    readProc.running = true
  }

  function markSeen() {
    lastSeen = Date.now()
    Quickshell.execDetached(["bash", "-c", "printf %s \"$1\" > \"$2\"", "--", String(lastSeen), seenPath])
  }

  function setDnd(value) {
    if (notificationService) notificationService.setDoNotDisturb(value)
    else Quickshell.execDetached(["omarchy-shell", "-q", "notifications", "setDnd", value ? "on" : "off"])
    fileDnd = value
  }

  function parse(raw) {
    var lines = String(raw || "").split("\n")
    var seen = ({})
    var rows = []
    var stamp = Date.now()
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.indexOf("D ") === 0) {
        try { fileDnd = JSON.parse(line.slice(2)).dnd === true } catch (e) {}
      } else if (line.indexOf("L ") === 0) {
        if (!seenLoaded) {
          lastSeen = Math.max(lastSeen, Number(line.slice(2)) || 0)
          seenLoaded = true
        }
      } else if (line.indexOf("N ") === 0) {
        var tab = line.indexOf("\t")
        if (tab === -1) continue
        var path = line.slice(2, tab)
        var stem = path.slice(path.lastIndexOf("/") + 1).replace(/\.json$/, "")
        if (seen[stem] || (hidden[stem] && hidden[stem] > stamp)) continue
        var entry
        try { entry = JSON.parse(line.slice(tab + 1)) } catch (e) { continue }
        if (!entry || typeof entry !== "object") continue
        seen[stem] = true
        rows.push({
          stem: stem,
          live: path.indexOf(historyDir) !== 0,
          app: String(entry.app || ""),
          summary: String(entry.summary || ""),
          body: String(entry.body || "").replace(/<[^>]*>/g, "").trim(),
          urgency: Number(entry.urgency) || 0,
          timestamp: Number(entry.timestamp) || 0
        })
      }
    }
    rows.sort(function(a, b) { return b.timestamp - a.timestamp })
    now = stamp
    entries = rows
    // The panel is showing them, so nothing that arrives while open is unread.
    if (popupOpen && unread > 0) markSeen()
  }

  function hide(stem) {
    var next = ({})
    for (var key in hidden) next[key] = hidden[key]
    next[stem] = Date.now() + 3000
    hidden = next
    entries = entries.filter(function(e) { return e.stem !== stem })
    settle.restart()
  }

  function remove(entry) {
    if (!/^[0-9]+-[0-9]+$/.test(entry.stem)) return
    var file = historyDir + entry.stem + ".json"
    var images = imagesDir + entry.stem
    if (entry.live) {
      // A toast still on screen: dismissing it archives it into history under
      // the same file name, so drop that once the service has moved it.
      Quickshell.execDetached(["bash", "-c",
        "omarchy-shell -q notifications dismiss \"$1\"; sleep 0.6; rm -f -- \"$2\" \"$3\"-*",
        "--", entry.summary, file, images])
    } else {
      Quickshell.execDetached(["bash", "-c", "rm -f -- \"$1\" \"$2\"-*", "--", file, images])
    }
    hide(entry.stem)
  }

  function clearAll() {
    // Both go through the service's own file queue, so the archive that
    // dismissAll triggers lands before clear empties the history.
    Quickshell.execDetached(["bash", "-c",
      "omarchy-shell -q notifications dismissAll; omarchy-shell -q notifications clear"])
    for (var i = 0; i < entries.length; i++) hidden[entries[i].stem] = Date.now() + 3000
    entries = []
    settle.restart()
  }

  function ago(timestamp) {
    var seconds = Math.max(0, Math.floor((now - timestamp) / 1000))
    if (seconds < 60) return "just now"
    if (seconds < 3600) return Math.floor(seconds / 60) + "m ago"
    if (seconds < 86400) return Math.floor(seconds / 3600) + "h ago"
    return Math.floor(seconds / 86400) + "d ago"
  }

  implicitWidth: row.implicitWidth + Style.space(14)
  implicitHeight: barSize

  Process {
    id: readProc
    running: false
    command: ["bash", "-c",
      "printf 'D %s\\n' \"$(tr -d '\\n' < \"$1\" 2>/dev/null)\"\n" +
      "printf 'L %s\\n' \"$(cat \"$2\" 2>/dev/null)\"\n" +
      "for f in \"$3\"*.json \"$4\"*.json; do\n" +
      "  [[ -e $f ]] || continue\n" +
      "  printf 'N %s\\t%s\\n' \"$f\" \"$(tr -d '\\n' < \"$f\")\"\n" +
      "done",
      "--", root.settingsPath, root.seenPath, root.popupDir, root.historyDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parse(text)
    }
  }

  Timer {
    interval: (root.popupOpen ? 1 : root.pollSeconds) * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Re-read once a removal has had time to reach the disk.
  Timer {
    id: settle
    interval: 1000
    onTriggered: root.refresh()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.setDnd(!root.dnd)
      else root.popupOpen = !root.popupOpen
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.dnd ? "Notifications silenced" : (root.unread > 0 ? root.unread + " new notification" + (root.unread === 1 ? "" : "s") : "Notifications"))
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(4)

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.dnd ? root.iconBellOff : root.iconBell
      color: root.unread > 0 && !root.dnd ? Color.accent : root.bar.barForeground
      opacity: root.unread > 0 || root.dnd ? 1.0 : 0.55
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      visible: root.showCount && root.unread > 0 && !root.vertical
      text: root.unread
      color: Color.accent
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Item {
        width: parent.width
        height: Math.max(heading.implicitHeight, actions.implicitHeight)

        Text {
          id: heading
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Notifications"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Row {
          id: actions
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: "Silence"
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.dnd
            foreground: root.bar.foreground
            onToggled: root.setDnd(!root.dnd)
          }

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.iconClearAll
            tooltipText: "Clear all"
            foreground: root.bar.foreground
            hoverColor: root.bar.foreground
            enabled: root.entries.length > 0
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.clearAll()
          }
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Text {
        width: parent.width
        visible: root.entries.length === 0
        horizontalAlignment: Text.AlignHCenter
        topPadding: Style.space(12)
        bottomPadding: Style.space(12)
        textFormat: Text.PlainText
        text: "No notifications"
        color: Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Flickable {
        id: listFlick
        width: parent.width
        height: Math.min(list.implicitHeight, Style.space(420))
        visible: root.entries.length > 0
        contentWidth: width
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: list
          width: listFlick.width
          spacing: Style.space(10)

          Repeater {
            model: root.entries

            Item {
              id: entryRow
              required property var modelData

              width: list.width
              height: Math.max(details.implicitHeight, removeButton.height)

              Column {
                id: details
                anchors.left: parent.left
                anchors.right: removeButton.left
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: entryRow.modelData.summary || entryRow.modelData.app || "Notification"
                  color: entryRow.modelData.urgency >= 2 ? root.bar.urgent : root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: text !== ""
                  textFormat: Text.PlainText
                  text: entryRow.modelData.body
                  color: Qt.darker(root.bar.foreground, 1.3)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.Wrap
                  maximumLineCount: 3
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: (entryRow.modelData.app && entryRow.modelData.summary ? entryRow.modelData.app + "  ·  " : "") + root.ago(entryRow.modelData.timestamp)
                  color: Qt.darker(root.bar.foreground, 1.6)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              PanelActionButton {
                id: removeButton
                anchors.right: parent.right
                anchors.top: parent.top
                iconText: root.iconClose
                tooltipText: "Remove"
                foreground: root.bar.foreground
                hoverColor: root.bar.foreground
                onClicked: root.remove(entryRow.modelData)
              }
            }
          }
        }
      }
    }
  }
}
