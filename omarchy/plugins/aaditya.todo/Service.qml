import QtQuick
import Quickshell
import Quickshell.Io

// Owns the to-do list. The bar widget and the desktop panel are views onto
// this one instance, so a task ticked in either place updates both.
//
// The list lives in ~/.local/state/omarchy/aaditya.todo/tasks.json rather
// than next to the plugin, because saving anything under plugins/ makes the
// shell hot-reload.
Item {
  id: root

  property var shell: null

  readonly property string dir: Quickshell.env("HOME") + "/.local/state/omarchy/aaditya.todo"
  readonly property string path: dir + "/tasks.json"

  property bool panelVisible: true
  property string panelPosition: "top-left" // top-left | top-right | bottom-left | bottom-right

  // Each task is { id, text, done, created }.
  property var tasks: []
  property bool loaded: false
  property int minted: 0

  readonly property var openTasks: tasks.filter(function(t) { return !t.done })
  readonly property int openCount: openTasks.length
  readonly property int doneCount: tasks.length - openCount
  // Open tasks first, each group oldest first.
  readonly property var sorted: openTasks.concat(tasks.filter(function(t) { return t.done }))

  function add(text) {
    var clean = String(text || "").replace(/\s+/g, " ").trim().slice(0, 200)
    if (!clean) return ""
    var stamp = Date.now()
    minted += 1
    var id = stamp.toString(36) + "-" + minted
    tasks = tasks.concat([{ id: id, text: clean, done: false, created: stamp }])
    save()
    return id
  }

  function toggle(id) {
    tasks = tasks.map(function(t) {
      return t.id === id ? { id: t.id, text: t.text, done: !t.done, created: t.created } : t
    })
    save()
  }

  function remove(id) {
    tasks = tasks.filter(function(t) { return t.id !== id })
    save()
  }

  function clearDone() {
    tasks = openTasks
    save()
  }

  function setPanelVisible(value) {
    if (panelVisible === value) return
    panelVisible = value
    save()
  }

  function setPanelPosition(value) {
    if (!/^(top|bottom)-(left|right)$/.test(value) || panelPosition === value) return
    panelPosition = value
    save()
  }

  function save() {
    if (loaded) write.restart()
  }

  function load(raw) {
    var saved = null
    try { saved = JSON.parse(raw) } catch (e) {}
    if (saved && typeof saved === "object") {
      if (typeof saved.panelVisible === "boolean") panelVisible = saved.panelVisible
      if (/^(top|bottom)-(left|right)$/.test(saved.panelPosition)) panelPosition = saved.panelPosition
      var rows = []
      var list = Array.isArray(saved.tasks) ? saved.tasks : []
      for (var i = 0; i < list.length; i++) {
        var t = list[i]
        if (!t || typeof t.text !== "string" || !t.text) continue
        rows.push({ id: String(t.id || "t" + i), text: t.text, done: t.done === true, created: Number(t.created) || 0 })
      }
      tasks = rows
    }
    loaded = true
  }

  Process {
    running: true
    command: ["bash", "-c", "mkdir -p \"$1\"; cat \"$2\" 2>/dev/null; true", "--", root.dir, root.path]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.load(text)
    }
  }

  // Coalesce writes: clearing several tasks is still one save.
  Timer {
    id: write
    interval: 100
    onTriggered: Quickshell.execDetached(["bash", "-c",
      "mkdir -p \"$1\" && printf '%s\\n' \"$3\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"",
      "--", root.dir, root.path,
      JSON.stringify({ panelVisible: root.panelVisible, panelPosition: root.panelPosition, tasks: root.tasks })])
  }

  IpcHandler {
    target: "aaditya.todo"

    function add(text: string): string { return root.add(text) ? "added" : "empty" }
    function toggle(id: string): string { root.toggle(id); return "ok" }
    function remove(id: string): string { root.remove(id); return "ok" }
    function clearDone(): string { root.clearDone(); return "ok" }
    function list(): string { return JSON.stringify(root.sorted) }
    function togglePanel(): string { root.setPanelVisible(!root.panelVisible); return root.panelVisible ? "shown" : "hidden" }
    function movePanel(position: string): string { root.setPanelPosition(position); return root.panelPosition }
  }
}
