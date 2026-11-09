import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// The Sticky Notes board (io.github.ruffbudda.sticky-notes) as an always-there,
// editable desktop widget on the layer just above the wallpaper. Drag it by its
// title row; the spot is remembered.
//
// It reads and writes the plugin's ~/.local/share/omarchy-sticky-notes/notes.json
// with the plugin's own rules (it is one more copy, like the plugin's one-per-bar
// copies), so notes edited here or in the bar panel stay in sync.
// Notes store, bento packing and note cards adapted from that plugin's Panel.qml
// (MIT, (c) RuffBudda).
Item {
  id: root

  property var shell: null

  // ── Position (dragged by the title row, saved to stateFile) ─────────────
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/aaditya.desktop-sticky"
  property string screenName: ""
  property real posX: -1           // -1 = not placed yet: top-center (clear of the todo and focus cards)
  property real posY: -1
  property bool stateLoaded: false

  readonly property var screen: {
    var list = Quickshell.screens
    for (var i = 0; i < list.length; i++) if (list[i].name === screenName) return list[i]
    return list.length > 0 ? list[0] : null
  }

  function saveState() {
    if (!stateLoaded) return
    stateFile.setText(JSON.stringify({ screen: screenName, x: Math.round(posX), y: Math.round(posY) }) + "\n")
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/state.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var s = JSON.parse(text())
        if (typeof s.screen === "string") root.screenName = s.screen
        if (typeof s.x === "number") root.posX = s.x
        if (typeof s.y === "number") root.posY = s.y
      } catch (e) {}
      root.stateLoaded = true
    }
    onLoadFailed: root.stateLoaded = true
  }
  Process {
    running: true
    command: ["mkdir", "-p", root.stateDir]
  }

  // ── Board state ─────────────────────────────────────────────────────────
  property bool showAll: false
  readonly property int compactLimit: 6
  readonly property int boardCols: showAll ? 6 : 4
  readonly property var board: computeBoard(store.rev, fitRev, boardCols, showAll)
  readonly property int count: notesModel.count

  property var fit: ({})
  property int fitRev: 0
  function setFit(id, w, h) {
    var f = fit[id]
    if (f && f.w === w && f.h === h) return
    fit[id] = { w: w, h: h }
    Qt.callLater(bumpFit)
  }
  function bumpFit() { fitRev++ }

  function computeBoard(_rev, _fit, cols, all) {
    var occ = [], rects = [], rows = 0
    function free(r, c, w, h) {
      for (var y = r; y < r + h; y++)
        for (var x = c; x < c + w; x++) if (occ[y] && occ[y][x]) return false
      return true
    }
    for (var i = 0; i < notesModel.count; i++) {
      if (!all && i >= compactLimit) { rects.push(null); continue }
      var f = fit[notesModel.get(i).noteId]
      var w = Math.min(f ? f.w : store.colsOf(store.sizeAt(i)), cols), h = f ? f.h : 1, done = false
      for (var r = 0; !done; r++) {
        for (var c = 0; c <= cols - w; c++) {
          if (!free(r, c, w, h)) continue
          for (var y = r; y < r + h; y++) { occ[y] = occ[y] || []; for (var x = c; x < c + w; x++) occ[y][x] = true }
          rects.push({ c: c, r: r, w: w, h: h })
          rows = Math.max(rows, r + h)
          done = true
          break
        }
      }
    }
    return { rects: rects, rows: rows }
  }

  readonly property color fg: Commons.Color.popups.text
  readonly property color accent: Commons.Color.accent
  readonly property color subtle: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
  readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.12)
  readonly property color raised: Qt.rgba(fg.r, fg.g, fg.b, 0.05)
  readonly property string uiFont: Style.font.family
  readonly property string noteFont: "sans-serif"

  function stamp(ms) {
    if (!ms) return ""
    var d = new Date(ms), now = new Date()
    if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, "HH:mm")
    var y = new Date(now); y.setDate(now.getDate() - 1)
    if (d.toDateString() === y.toDateString()) return "Yesterday"
    return Qt.formatDate(d, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy")
  }

  ListModel { id: notesModel }

  // ── Notes store (same file format and sync rules as the plugin) ─────────
  QtObject {
    id: store

    readonly property string dataDir: Quickshell.env("HOME") + "/.local/share/omarchy-sticky-notes"
    property bool loaded: false
    property bool storageReady: false
    property string storageError: ""
    property string lastAddedId: ""
    property string lastColor: "yellow"
    property string lastWritten: ""
    property int rev: 0
    readonly property string paper: "#fff176"

    function colsOf(sz) { return sz === "w" || sz === "l" ? 2 : 1 }
    function sizeAt(i) {
      var n = notesModel.get(i)
      if (!n) return "s"
      if (n.size) return n.size
      var t = n.text || "", lines = t.split("\n").length
      if (t.length > 140 || lines >= 9) return "l"
      if (lines >= 5) return "t"
      if (t.length > 70) return "w"
      return "s"
    }
    function cycleSize(id) {
      var i = indexOf(id)
      if (i < 0) return
      notesModel.setProperty(i, "size", colsOf(sizeAt(i)) === 2 ? "s" : "w")
      rev++
      save()
    }
    function indexOf(id) {
      for (var i = 0; i < notesModel.count; i++) if (notesModel.get(i).noteId === id) return i
      return -1
    }
    function addNote() {
      if (storageError !== "" || !loaded) return ""
      var id = String(Date.now()) + Math.floor(Math.random() * 1000)
      lastAddedId = id
      notesModel.insert(pinnedCount(), { noteId: id, colorKey: "yellow", text: "", updated: Date.now(), pinned: false, size: "w" })
      rev++
      save()
      return id
    }
    function pinnedCount() {
      var n = 0
      for (var i = 0; i < notesModel.count; i++) if (notesModel.get(i).pinned) n++
      return n
    }
    function togglePin(id) {
      var i = indexOf(id)
      if (i < 0) return
      var pin = !notesModel.get(i).pinned
      notesModel.setProperty(i, "pinned", pin)
      notesModel.move(i, pin ? 0 : pinnedCount(), 1)
      rev++
      save()
    }
    function deleteNote(id) {
      var i = indexOf(id)
      if (i < 0) return
      notesModel.remove(i)
      rev++
      save()
    }
    function update(id, props) {
      var i = indexOf(id)
      if (i < 0) return
      for (var k in props) notesModel.setProperty(i, k, props[k])
      notesModel.setProperty(i, "updated", Date.now())
      rev++
      saveTimer.restart()
    }
    function serialize() {
      var list = []
      for (var i = 0; i < notesModel.count; i++) {
        var n = notesModel.get(i)
        list.push({ id: n.noteId, color: n.colorKey, text: n.text, updated: n.updated, pinned: n.pinned, size: n.size })
      }
      return JSON.stringify({ version: 2, lastColor: lastColor, notes: list }, null, 2) + "\n"
    }
    function save() {
      saveTimer.stop()
      if (!loaded) return
      lastWritten = serialize()
      dataFile.setText(lastWritten)
    }
    function load(raw) {
      if (raw === lastWritten) { loaded = true; return }
      // A half-written or broken file must not clear the notes (the next save
      // would write that loss to disk): keep what we have and don't save over it.
      var data, list
      try {
        data = JSON.parse(raw)
        if (!data || typeof data !== "object" || Array.isArray(data)) throw "not a notes file"
        list = data.notes === undefined ? [] : data.notes
        if (!Array.isArray(list)) throw "notes is not a list"
        for (var j = 0; j < list.length; j++)
          if (!list[j] || typeof list[j] !== "object") throw "note " + j + " is not an object"
      } catch (e) {
        console.warn("desktop-sticky: could not read notes.json, keeping the notes in memory: " + e)
        return
      }
      lastWritten = raw
      if (data.lastColor) lastColor = String(data.lastColor)
      notesModel.clear()
      for (var i = 0; i < list.length; i++)
        notesModel.append({
          noteId: String(list[i].id), colorKey: String(list[i].color || "yellow"),
          text: String(list[i].text || ""), updated: Number(list[i].updated) || 0,
          pinned: list[i].pinned === true,
          size: ["s", "w", "t", "l"].indexOf(list[i].size) >= 0 ? list[i].size : ""
        })
      loaded = true
      rev++
    }
  }

  Timer { id: saveTimer; interval: 400; onTriggered: store.save() }
  Component.onDestruction: if (saveTimer.running) store.save()

  // Same ownership/permission check as the plugin before touching the notes:
  // owner-only folder and file, notes.json a real file (not a symlink) and yours.
  Process {
    running: true
    command: ["sh", "-c",
      'umask 077; d="$1"; f="$d/notes.json"; ' +
      'mkdir -p -- "$d" || exit 1; ' +
      '[ -d "$d" ] && [ -O "$d" ] || exit 2; ' +
      'chmod 700 -- "$d" || exit 1; ' +
      'if [ -L "$f" ]; then exit 3; fi; ' +
      'if [ -e "$f" ]; then ' +
        '[ -f "$f" ] || exit 3; [ -O "$f" ] || exit 4; chmod 600 -- "$f" || exit 1; ' +
      'else printf \'{ "version": 2, "notes": [] }\\n\' > "$f" || exit 1; fi',
      "sh", store.dataDir]
    onExited: function(exitCode) {
      if (exitCode === 0) { store.storageReady = true; return }
      var why = {
        2: "the folder is not owned by your account",
        3: "notes.json is a symlink or not a regular file",
        4: "notes.json is not owned by your account"
      }[exitCode] || "it could not be made private (owner-only)"
      store.storageError = "Notes not loaded: " + why + "."
    }
  }

  FileView {
    id: dataFile
    path: store.storageReady ? store.dataDir + "/notes.json" : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: if (!saveTimer.running) store.load(text())
    onLoadFailed: if (store.storageReady) store.loaded = true
  }

  // ── The desktop window ──────────────────────────────────────────────────
  PanelWindow {
    id: win
    screen: root.screen
    visible: root.stateLoaded && root.screen !== null
    color: "transparent"

    readonly property real maxX: Math.max(0, (screen ? screen.width : 0) - width)
    readonly property real maxY: Math.max(0, (screen ? screen.height : 0) - height)
    function clampX(x) { return Math.round(Math.min(Math.max(0, x), maxX)) }
    function clampY(y) { return Math.round(Math.min(Math.max(0, y), maxY)) }

    anchors { top: true; left: true }
    margins {
      left: root.posX < 0 ? win.clampX(((win.screen ? win.screen.width : 0) - win.width) / 2) : win.clampX(root.posX)
      top: root.posY < 0 ? Style.gapsOut * 2 : win.clampY(root.posY)
    }
    implicitWidth: frame.width
    implicitHeight: frame.height

    WlrLayershell.namespace: "aaditya-desktop-sticky"
    WlrLayershell.layer: WlrLayer.Bottom
    // Takes the keyboard only after you click into it, so typing in a note works.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    Rectangle {
      id: frame
      readonly property real pad: Style.space(18)
      width: root.showAll ? Style.space(980) : Style.space(640)
      height: layout.implicitHeight + pad * 2
      radius: Style.cornerRadius
      color: Commons.Color.popups.background
      border.width: 2
      border.color: Commons.Color.popups.border

      // Clicking empty board space drops focus out of a note.
      MouseArea {
        anchors.fill: parent
        onClicked: frame.forceActiveFocus()
      }

      Column {
        id: layout
        x: frame.pad
        y: frame.pad
        width: frame.width - frame.pad * 2
        spacing: Style.space(14)

        Shortcut {
          sequence: "Ctrl+N"
          context: Qt.WindowShortcut
          onActivated: { store.addNote(); flick.contentY = 0 }
        }

        // Title row; also the drag handle for the whole board.
        Item {
          id: header
          width: parent.width
          height: Style.space(28)

          MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real pressX: 0
            property real pressY: 0
            // The window moves under the cursor, so the cursor stays at the
            // same local spot; each move is the offset from where it was grabbed.
            onPressed: function(m) {
              pressX = m.x; pressY = m.y
              if (root.posX < 0) { root.posX = win.margins.left; root.posY = win.margins.top }
              if (win.screen) root.screenName = win.screen.name
            }
            onPositionChanged: function(m) {
              root.posX = win.clampX(root.posX + m.x - pressX)
              root.posY = win.clampY(root.posY + m.y - pressY)
            }
            onReleased: root.saveState()
          }

          Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: Style.space(10)
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: ""
              color: root.accent
              font.family: root.uiFont
              font.pixelSize: Style.space(17)
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Sticky notes"
              color: root.fg
              font.family: root.uiFont
              font.pixelSize: Style.space(15)
              font.weight: Font.DemiBold
            }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.count > 0
              height: Style.space(18)
              width: Math.max(height, countText.implicitWidth + Style.space(12))
              radius: height / 2
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
              Text {
                id: countText
                anchors.centerIn: parent
                text: root.count
                color: root.accent
                font.family: root.uiFont
                font.pixelSize: Style.space(11)
                font.weight: Font.DemiBold
              }
            }
          }

          Rectangle {
            id: newBtn
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            height: Style.space(28)
            width: height
            radius: Style.space(7)
            color: newMouse.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent
            Text {
              anchors.centerIn: parent
              text: "+"
              color: "#ffffff"
              font.family: root.noteFont
              font.pixelSize: Style.space(20)
              font.weight: Font.Bold
            }
            MouseArea {
              id: newMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { store.addNote(); flick.contentY = 0 }
            }
          }

          Rectangle {
            id: viewAll
            anchors { right: newBtn.left; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
            visible: root.count > root.compactLimit || root.showAll
            height: Style.space(26)
            width: viewAllText.implicitWidth + Style.space(20)
            radius: Style.space(6)
            color: viewAllMouse.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : root.raised
            border.width: 1
            border.color: viewAllMouse.containsMouse ? root.accent : root.hairline
            Text {
              id: viewAllText
              anchors.centerIn: parent
              text: root.showAll ? "Show less" : "View all (" + root.count + ")"
              color: root.fg
              font.family: root.uiFont
              font.pixelSize: Style.space(12)
            }
            MouseArea {
              id: viewAllMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.showAll = !root.showAll; flick.contentY = 0 }
            }
          }
        }

        Item {
          id: notesArea
          width: parent.width
          height: root.count === 0 ? Style.space(150)
            : root.showAll ? Math.min(grid.implicitHeight, Style.space(780))
            : Math.min(grid.implicitHeight, Style.space(600))

          Column {
            visible: root.count === 0
            anchors.centerIn: parent
            spacing: Style.space(8)
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: ""
              color: root.hairline
              font.family: root.uiFont
              font.pixelSize: Style.space(40)
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: store.storageError !== "" ? "Notes are turned off" : "No notes yet"
              color: root.fg
              font.family: root.uiFont
              font.pixelSize: Style.space(13)
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.min(implicitWidth, notesArea.width - Style.space(32))
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              text: store.storageError !== "" ? store.storageError : "Click + to start one"
              color: root.subtle
              font.family: root.uiFont
              font.pixelSize: Style.space(11)
            }
          }

          Flickable {
            id: flick
            anchors.fill: parent
            visible: root.count > 0
            contentWidth: width
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            function reveal(item, r) {
              var y = item.mapToItem(grid, r.x, r.y).y
              if (y < contentY) contentY = y
              else if (y + r.height > contentY + height) contentY = y + r.height - height
            }

            Item {
              id: grid
              width: flick.width
              readonly property real gap: Style.space(12)
              readonly property real cell: (width - gap * (root.boardCols - 1)) / root.boardCols
              readonly property real rowH: Style.space(8)
              readonly property real maxCardH: 2 * Math.round(cell * 0.82) + gap
              implicitHeight: root.board.rows > 0 ? root.board.rows * rowH + (root.board.rows - 1) * gap : 0
              height: implicitHeight

              Repeater {
                model: notesModel
                delegate: NoteCard {
                  readonly property var rect: root.board.rects[index] || null
                  visible: rect !== null
                  x: rect ? rect.c * (grid.cell + grid.gap) : 0
                  y: rect ? rect.r * (grid.rowH + grid.gap) : 0
                  width: rect ? rect.w * grid.cell + (rect.w - 1) * grid.gap : 0
                  height: rect ? rect.h * grid.rowH + (rect.h - 1) * grid.gap : 0
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: (!root.showAll && root.count > root.compactLimit
                  ? (root.count - root.compactLimit) + " more in View all  ·  " : "")
                + "Ctrl+N new note  ·  Pinned notes stay on top  ·  Drag the title to move"
          color: root.subtle
          opacity: 0.8
          font.family: root.uiFont
          font.pixelSize: Style.space(10)
        }
      }
    }
  }

  // ── One note card ─────────────────────────────────────────────────────
  component NoteCard: Item {
    id: card
    required property int index
    required property string noteId
    required property string colorKey
    required property string text
    required property real updated
    required property bool pinned

    property bool confirmDelete: false
    readonly property color ink: "#262626"
    readonly property color inkSoft: Qt.rgba(ink.r, ink.g, ink.b, 0.5)
    readonly property color paper: store.paper
    property bool settled: false
    Behavior on x { enabled: card.settled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: card.settled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on width { enabled: card.settled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: card.settled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    readonly property bool hot: cardHover.hovered || body.activeFocus
    readonly property int fold: Style.space(18)

    readonly property int prefCols: { store.rev; return Math.min(store.colsOf(store.sizeAt(index)), root.boardCols) }
    readonly property int maxCols: Math.max(prefCols, Math.min(4, root.boardCols))
    function bodyWFor(c) { return c * grid.cell + (c - 1) * grid.gap - Style.space(28) }
    readonly property var probeH: [probe1.contentHeight, probe2.contentHeight, probe3.contentHeight, probe4.contentHeight]
    readonly property int cols: {
      var best = prefCols
      for (var c = prefCols; c <= maxCols; c++) {
        if (bodyTop + probeH[c - 1] + footH <= grid.maxCardH) return c
        if (probeH[c - 1] < probeH[best - 1] - 0.5) best = c
      }
      return best
    }
    readonly property real bodyW: bodyWFor(cols)
    readonly property real bodyTop: Style.space(34)
    readonly property real footH: Style.space(4) + Math.max(when.height, Style.space(14)) + Style.space(9)
    readonly property real needH: bodyTop + body.contentHeight + footH
    readonly property int fitRows: Math.max(1, Math.ceil((needH + grid.gap) / (grid.rowH + grid.gap) - 0.001))
    onColsChanged: root.setFit(noteId, cols, fitRows)
    onFitRowsChanged: root.setFit(noteId, cols, fitRows)
    // Text changed in the bar panel: show it here unless we're typing in this note.
    onTextChanged: if (!body.activeFocus && body.text !== text) body.text = text

    Text { id: probe1; visible: false; width: card.bodyWFor(1); text: body.text; font: body.font; wrapMode: Text.Wrap; textFormat: Text.PlainText }
    Text { id: probe2; visible: false; width: card.bodyWFor(2); text: body.text; font: body.font; wrapMode: Text.Wrap; textFormat: Text.PlainText }
    Text { id: probe3; visible: false; width: card.bodyWFor(3); text: body.text; font: body.font; wrapMode: Text.Wrap; textFormat: Text.PlainText }
    Text { id: probe4; visible: false; width: card.bodyWFor(4); text: body.text; font: body.font; wrapMode: Text.Wrap; textFormat: Text.PlainText }

    HoverHandler { id: cardHover }

    Component.onCompleted: {
      body.text = card.text
      root.setFit(noteId, cols, fitRows)
      Qt.callLater(function() { card.settled = true })
      if (store.lastAddedId === noteId) {
        store.lastAddedId = ""
        Qt.callLater(function() { body.forceActiveFocus() })
      }
    }

    Rectangle {
      anchors.fill: paperRect
      anchors.topMargin: Style.space(3)
      anchors.leftMargin: Style.space(1)
      anchors.rightMargin: -Style.space(1)
      anchors.bottomMargin: -Style.space(4)
      radius: paperRect.radius
      color: "#000000"
      opacity: body.activeFocus ? 0.6 : card.hot ? 0.45 : 0.3
    }

    Canvas {
      id: paperRect
      anchors.fill: parent
      property real radius: Style.space(8)
      property color fill: card.paper
      onFillChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var c = getContext("2d"), w = width, h = height, r = radius, f = card.fold
        c.reset()
        c.beginPath()
        c.moveTo(r, 0); c.lineTo(w - r, 0); c.arcTo(w, 0, w, r, r)
        c.lineTo(w, h - f); c.lineTo(w - f, h)
        c.lineTo(r, h); c.arcTo(0, h, 0, h - r, r)
        c.lineTo(0, r); c.arcTo(0, 0, r, 0, r)
        c.closePath()
        c.fillStyle = fill
        c.fill()
        c.beginPath()
        c.moveTo(w, h - f); c.lineTo(w - f, h - f); c.lineTo(w - f, h); c.closePath()
        c.fillStyle = Qt.rgba(fill.r * 0.84, fill.g * 0.84, fill.b * 0.84, 1)
        c.fill()
      }
    }

    Row {
      anchors { top: parent.top; right: parent.right; topMargin: Style.space(6); rightMargin: Style.space(6) }
      spacing: Style.space(2)
      opacity: card.hot || card.confirmDelete ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }

      CardButton {
        glyph: ""   // pin
        ink: card.ink
        active: card.pinned
        onClicked: store.togglePin(card.noteId)
      }
      CardButton {
        glyph: ""   // resize: narrow <-> wide
        ink: card.ink
        onClicked: store.cycleSize(card.noteId)
      }
      CardButton {
        glyph: ""   // trash; turns red, click again to delete
        ink: card.confirmDelete ? "#e53935" : card.ink
        onClicked: {
          if (card.confirmDelete || body.text.trim() === "") store.deleteNote(card.noteId)
          else { card.confirmDelete = true; confirmTimer.restart() }
        }
      }
    }
    Timer { id: confirmTimer; interval: 3000; onTriggered: card.confirmDelete = false }

    TextEdit {
      id: body
      x: Style.space(14)
      y: card.bodyTop
      width: card.bodyW
      height: Math.max(contentHeight, card.height - card.bodyTop - card.footH)
      wrapMode: TextEdit.Wrap
      textFormat: TextEdit.PlainText
      selectByMouse: true
      color: card.ink
      selectionColor: Qt.darker(card.paper, 1.3)
      selectedTextColor: card.ink
      font.family: root.noteFont
      font.pixelSize: Style.space(14)
      onTextChanged: if (text !== card.text) store.update(card.noteId, { text: text })
      onCursorRectangleChanged: if (activeFocus) flick.reveal(body, cursorRectangle)
      Keys.onEscapePressed: frame.forceActiveFocus()

      Text {
        visible: body.text === "" && !body.activeFocus
        text: "Write something…"
        color: card.inkSoft
        font: body.font
      }
    }

    Text {
      visible: card.pinned
      anchors { left: parent.left; top: parent.top; leftMargin: Style.space(12); topMargin: Style.space(9) }
      text: ""
      color: card.ink
      rotation: -30
      font.family: root.uiFont
      font.pixelSize: Style.space(13)
    }

    Text {
      id: when
      anchors { left: parent.left; bottom: parent.bottom; leftMargin: Style.space(14); bottomMargin: Style.space(9) }
      text: root.stamp(card.updated)
      color: card.inkSoft
      font.family: root.noteFont
      font.pixelSize: Style.space(10)
    }
  }

  component CardButton: Rectangle {
    id: btn
    property string glyph: ""
    property color ink: "#262626"
    property bool active: false
    signal clicked()
    height: Style.space(24)
    width: height
    radius: Style.space(6)
    color: (hover.containsMouse || active) ? Qt.rgba(ink.r, ink.g, ink.b, 0.14) : "transparent"
    Text {
      anchors.centerIn: parent
      text: btn.glyph
      color: btn.ink
      font.family: root.uiFont
      font.pixelSize: Style.space(13)
    }
    MouseArea {
      id: hover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.clicked()
    }
  }
}
