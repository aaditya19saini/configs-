import QtQuick
import Quickshell
import Quickshell.Io
import "FocusData.js" as FocusData

// Owns the focus timer and its history. The bar widget and the desktop panel
// are views onto this one instance, so every monitor shows the same session.
//
// Files live in ~/.local/state/omarchy/aaditya.focus/ rather than next to the
// plugin, because saving anything under plugins/ makes the shell hot-reload:
//   settings.json   timer customisation
//   state.json      the session in progress, so a shell restart resumes it
//   sessions.jsonl  one line per uninterrupted stretch of focus
Item {
  id: root

  property var shell: null

  readonly property string dir: Quickshell.env("HOME") + "/.local/state/omarchy/aaditya.focus"
  readonly property string settingsPath: dir + "/settings.json"
  readonly property string statePath: dir + "/state.json"
  readonly property string logPath: dir + "/sessions.jsonl"

  // Settings. Durations are minutes.
  property real focusMinutes: 25
  property real shortBreakMinutes: 5
  property real longBreakMinutes: 15
  property int rounds: 4
  property int longBreakEvery: 4
  property bool breaksEnabled: true
  property bool longBreaksEnabled: true
  property bool autoStart: true
  property bool panelVisible: true
  property string panelPosition: "top-right"
  property int panelWeeks: 26
  property bool soundEnabled: true
  property string soundFile: "/usr/share/sounds/freedesktop/stereo/complete.oga"

  // Session.
  property string phase: "idle" // idle | focus | break
  property bool paused: false
  property int round: 1
  property string name: ""
  property real endsAt: 0
  property real pausedRemaining: 0
  property real phaseTotal: 0
  // Start of the focus stretch being timed right now; 0 when none is.
  property real segmentStart: 0

  property bool loaded: false
  property real now: Date.now()
  property real lastTick: Date.now()
  // Coarse clock so the graph is not rebuilt every second.
  property real minuteNow: Date.now()

  readonly property bool active: phase !== "idle"
  readonly property bool running: active && !paused
  readonly property real remaining: !active ? 0 : (paused ? pausedRemaining : Math.max(0, endsAt - now))
  readonly property string clockText: FocusData.clock(remaining)
  readonly property bool longBreak: phase === "break" && longBreakDue
  readonly property bool longBreakDue: longBreaksEnabled && round % Math.max(1, longBreakEvery) === 0
  readonly property string phaseLabel: phase === "focus" ? "Focus" : (phase === "break" ? (longBreak ? "Long break" : "Break") : "Idle")

  property var entries: []
  readonly property var days: FocusData.aggregate(entries, segmentStart > 0 ? { start: segmentStart, end: Math.max(segmentStart, minuteNow), name: name } : null)
  readonly property int todaySeconds: FocusData.secondsOn(days, FocusData.dayKey(new Date(minuteNow)))
  readonly property int streak: FocusData.streak(days, minuteNow)

  function minutesFor(nextPhase) {
    if (nextPhase === "focus") return focusMinutes
    return longBreakDue ? longBreakMinutes : shortBreakMinutes
  }

  function begin(nextPhase, startPaused) {
    var stamp = Date.now()
    phase = nextPhase
    phaseTotal = Math.max(1000, minutesFor(nextPhase) * 60000)
    paused = startPaused
    pausedRemaining = startPaused ? phaseTotal : 0
    endsAt = startPaused ? 0 : stamp + phaseTotal
    segmentStart = !startPaused && nextPhase === "focus" ? stamp : 0
    now = stamp
    lastTick = stamp
    minuteNow = stamp
    saveState()
  }

  function reset() {
    phase = "idle"
    paused = false
    round = 1
    endsAt = 0
    pausedRemaining = 0
    phaseTotal = 0
    segmentStart = 0
    saveState()
  }

  function start(sessionName) {
    if (active) return
    name = String(sessionName || "").trim()
    round = 1
    begin("focus", false)
  }

  function pause() {
    if (!running) return
    var stamp = Date.now()
    pausedRemaining = Math.max(0, endsAt - stamp)
    closeSegment(stamp, false)
    paused = true
    saveState()
  }

  function resume() {
    if (!active || !paused) return
    var stamp = Date.now()
    endsAt = stamp + pausedRemaining
    paused = false
    segmentStart = phase === "focus" ? stamp : 0
    now = stamp
    lastTick = stamp
    saveState()
  }

  function toggle() {
    if (!active) start(name)
    else if (paused) resume()
    else pause()
  }

  function stop() {
    if (!active) return
    closeSegment(Date.now(), false)
    reset()
  }

  function skipBreak() {
    if (phase !== "break") return
    afterBreak(false)
  }

  function afterBreak(startPaused) {
    if (round >= rounds) {
      notify("Session complete", sessionSummary())
      reset()
      return
    }
    round += 1
    begin("focus", startPaused)
  }

  function finishPhase() {
    if (phase === "focus") {
      closeSegment(endsAt, true)
      chime()
      if (breaksEnabled) {
        begin("break", !autoStart)
        notify("Focus block done", "Time for a " + Math.round(phaseTotal / 60000) + " minute " + (longBreak ? "long break" : "break"))
      } else if (round >= rounds) {
        notify("Session complete", sessionSummary())
        reset()
      } else {
        round += 1
        begin("focus", !autoStart)
        notify("Focus block done", "Round " + round + " of " + rounds + (autoStart ? " started" : " is ready"))
      }
    } else if (phase === "break") {
      var last = round >= rounds
      afterBreak(!autoStart)
      if (!last) notify("Break over", "Round " + round + " of " + rounds + (autoStart ? " started" : " is ready"))
    }
  }

  function sessionSummary() {
    return (name ? name + "  ·  " : "") + FocusData.duration(todaySeconds) + " focused today"
  }

  // Record the focus stretch that began at segmentStart, if there is one.
  function closeSegment(end, completed) {
    var begun = segmentStart
    segmentStart = 0
    if (!(begun > 0) || end - begun < 1000) return
    var entry = { start: begun, end: end, seconds: Math.round((end - begun) / 1000), name: name, completed: completed }
    entries = entries.concat([{ start: begun, end: end, name: name }])
    Quickshell.execDetached(["bash", "-c", "mkdir -p \"$1\" && printf '%s\\n' \"$3\" >> \"$2\"",
      "--", dir, logPath, JSON.stringify(entry)])
  }

  function notify(title, body) {
    Quickshell.execDetached(["notify-send", "-a", "Focus", title, body])
  }

  function chime() {
    if (soundEnabled && soundFile) Quickshell.execDetached(["pw-play", soundFile])
  }

  function writeFile(path, value) {
    Quickshell.execDetached(["bash", "-c", "mkdir -p \"$1\" && printf '%s\\n' \"$3\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"",
      "--", dir, path, JSON.stringify(value)])
  }

  function saveState() {
    if (loaded) stateWrite.restart()
  }

  function setSetting(key, value) {
    if (!(key in settingDefaults) || root[key] === value) return
    root[key] = value
    if (loaded) settingsWrite.restart()
  }

  readonly property var settingDefaults: ({
    focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, rounds: 4, longBreakEvery: 4,
    breaksEnabled: true, longBreaksEnabled: true, autoStart: true, panelVisible: true, panelPosition: "top-right", panelWeeks: 26,
    soundEnabled: true, soundFile: "/usr/share/sounds/freedesktop/stereo/complete.oga"
  })

  function currentSettings() {
    var out = ({})
    for (var key in settingDefaults) out[key] = root[key]
    return out
  }

  function applySettings(raw) {
    var saved
    try { saved = JSON.parse(raw) } catch (e) { return }
    if (!saved || typeof saved !== "object") return
    for (var key in settingDefaults) {
      var fallback = settingDefaults[key]
      var value = saved[key]
      if (typeof value !== typeof fallback) continue
      if (typeof fallback === "number" && !(value > 0)) continue
      root[key] = value
    }
  }

  function restoreState(raw) {
    var saved
    try { saved = JSON.parse(raw) } catch (e) { return }
    if (!saved || (saved.phase !== "focus" && saved.phase !== "break")) return
    var stamp = Date.now()
    phase = saved.phase
    round = Math.max(1, Number(saved.round) || 1)
    name = String(saved.name || "")
    phaseTotal = Number(saved.phaseTotal) || 0
    if (saved.paused === true) {
      paused = true
      pausedRemaining = Number(saved.pausedRemaining) || 0
      return
    }
    endsAt = Number(saved.endsAt) || 0
    segmentStart = Number(saved.segmentStart) || 0
    var heartbeat = Number(saved.heartbeat) || 0
    if (stamp - heartbeat > 5 * 60000) {
      // The shell was gone for a while (reboot, crash): only count the time
      // it was known to be running, and leave the session paused.
      closeSegment(heartbeat, false)
      pausedRemaining = Math.max(0, endsAt - heartbeat)
      paused = true
    } else if (stamp >= endsAt) {
      now = stamp
      finishPhase()
    }
  }

  function load(raw) {
    var lines = String(raw || "").split("\n")
    var log = []
    var state = ""
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.indexOf("S ") === 0) applySettings(line.slice(2))
      else if (line.indexOf("T ") === 0) state = line.slice(2)
      else if (line.indexOf("E ") === 0) log.push(line.slice(2))
    }
    entries = FocusData.parseLog(log.join("\n"))
    now = Date.now()
    lastTick = now
    minuteNow = now
    loaded = true
    restoreState(state)
    saveState()
  }

  function tick() {
    var stamp = Date.now()
    if (running && stamp - lastTick > 5 * 60000) {
      // The machine was asleep. Time away is not focus: bank what was done
      // before it slept and wait for the user to resume.
      pausedRemaining = Math.max(0, endsAt - lastTick)
      closeSegment(lastTick, false)
      paused = true
      saveState()
    }
    lastTick = stamp
    now = stamp
    if (Math.floor(stamp / 60000) !== Math.floor(minuteNow / 60000)) {
      minuteNow = stamp
      if (running) saveState()
    }
    if (running && stamp >= endsAt) finishPhase()
  }

  Process {
    id: readProc
    running: true
    command: ["bash", "-c",
      "mkdir -p \"$1\"\n" +
      "printf 'S %s\\n' \"$(tr -d '\\n' < \"$2\" 2>/dev/null)\"\n" +
      "printf 'T %s\\n' \"$(tr -d '\\n' < \"$3\" 2>/dev/null)\"\n" +
      "[[ -e $4 ]] && sed 's/^/E /' \"$4\"\n" +
      "true",
      "--", root.dir, root.settingsPath, root.statePath, root.logPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.load(text)
    }
  }

  Timer {
    interval: root.running ? 1000 : 30000
    repeat: true
    running: root.loaded
    onTriggered: root.tick()
  }

  // Coalesce writes: one transition can touch the state several times.
  Timer {
    id: stateWrite
    interval: 50
    onTriggered: root.writeFile(root.statePath, {
      phase: root.phase, paused: root.paused, round: root.round, name: root.name,
      endsAt: root.endsAt, pausedRemaining: root.pausedRemaining, phaseTotal: root.phaseTotal,
      segmentStart: root.segmentStart, heartbeat: Date.now()
    })
  }

  Timer {
    id: settingsWrite
    interval: 300
    onTriggered: root.writeFile(root.settingsPath, root.currentSettings())
  }

  IpcHandler {
    target: "aaditya.focus"

    function start(name: string): string { root.start(name); return root.phase }
    function toggle(): string { root.toggle(); return root.paused ? "paused" : root.phase }
    function pause(): string { root.pause(); return root.phase }
    function resume(): string { root.resume(); return root.phase }
    function skipBreak(): string { root.skipBreak(); return root.phase }
    function stop(): string { root.stop(); return root.phase }
    function togglePanel(): string { root.setSetting("panelVisible", !root.panelVisible); return root.panelVisible ? "shown" : "hidden" }
    function status(): string {
      return JSON.stringify({ phase: root.phase, paused: root.paused, round: root.round, rounds: root.rounds,
        name: root.name, remaining: root.clockText, todaySeconds: root.todaySeconds, streak: root.streak })
    }
  }
}
