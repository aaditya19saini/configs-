import QtQuick
import Quickshell
import Quickshell.Io
import "Alarms.js" as Alarms

// Owns the alarms and timers. The bar label and the clock slide of the popup
// are views onto this one instance, so they keep counting while the popup is
// closed and every monitor shows the same thing.
//
// State lives in ~/.local/state/omarchy/aaditya.clock/state.json rather than
// next to the plugin, because saving anything under plugins/ makes the shell
// hot-reload.
Item {
  id: root

  property var shell: null

  readonly property string dir: Quickshell.env("HOME") + "/.local/state/omarchy/aaditya.clock"
  readonly property string statePath: dir + "/state.json"
  readonly property string soundFile: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

  // Something that came due this long ago is announced, not rung: nobody
  // wants the 07:00 alarm going off when the lid opens at noon.
  readonly property int graceMs: 10 * 60000
  readonly property int ringMs: 2 * 60000
  readonly property int snoozeMinutes: 5

  // { id, hour, minute, label, days, enabled, nextAt }
  property var alarms: []
  // { id, label, total, endsAt, pausedRemaining }; paused when endsAt is 0.
  property var timers: []
  property int nextId: 1

  // What is going off right now: { kind, title, body }, else null.
  property var ringing: null
  property real ringUntil: 0

  property bool loaded: false
  property real now: Date.now()

  readonly property bool hasRunningTimer: timers.some(function(timer) { return timer.endsAt > 0 })
  readonly property int armedAlarms: alarms.filter(function(alarm) { return alarm.enabled }).length
  readonly property bool busy: hasRunningTimer || armedAlarms > 0 || ringing !== null

  // The running timer closest to finishing, for the bar label.
  readonly property string nearestTimerText: {
    var best = 0
    for (var i = 0; i < timers.length; i++) {
      var endsAt = timers[i].endsAt
      if (endsAt > 0 && (best === 0 || endsAt < best)) best = endsAt
    }
    return best > 0 ? Alarms.countdown(best - now) : ""
  }

  function timerRemaining(timer) {
    return timer.endsAt > 0 ? Math.max(0, timer.endsAt - now) : timer.pausedRemaining
  }

  function allocateId() {
    var id = nextId
    nextId += 1
    return id
  }

  // ---- Alarms.

  function addAlarm(hour, minute, label, days) {
    var repeat = Alarms.cleanDays(days)
    alarms = alarms.concat([{
      id: allocateId(), hour: hour, minute: minute, label: String(label || "").trim(),
      days: repeat, enabled: true, nextAt: Alarms.nextOccurrence(hour, minute, repeat, Date.now())
    }])
    save()
  }

  function setAlarmEnabled(id, enabled) {
    var stamp = Date.now()
    alarms = alarms.map(function(alarm) {
      if (alarm.id !== id) return alarm
      var next = Object.assign({}, alarm, { enabled: enabled })
      next.nextAt = enabled ? Alarms.nextOccurrence(alarm.hour, alarm.minute, alarm.days, stamp) : 0
      return next
    })
    save()
  }

  function removeAlarm(id) {
    alarms = alarms.filter(function(alarm) { return alarm.id !== id })
    save()
  }

  // ---- Timers.

  function addTimer(minutes, label) {
    var total = Math.round(Number(minutes) * 60000)
    if (!(total >= 1000)) return false
    var stamp = Date.now()
    now = stamp
    timers = timers.concat([{
      id: allocateId(), label: String(label || "").trim(), total: total, endsAt: stamp + total, pausedRemaining: 0
    }])
    save()
    return true
  }

  function toggleTimer(id) {
    var stamp = Date.now()
    now = stamp
    timers = timers.map(function(timer) {
      if (timer.id !== id) return timer
      if (timer.endsAt > 0)
        return Object.assign({}, timer, { endsAt: 0, pausedRemaining: Math.max(1000, timer.endsAt - stamp) })
      return Object.assign({}, timer, { endsAt: stamp + timer.pausedRemaining, pausedRemaining: 0 })
    })
    save()
  }

  function removeTimer(id) {
    timers = timers.filter(function(timer) { return timer.id !== id })
    save()
  }

  // ---- Going off.

  function due(title, body, late) {
    if (late > graceMs) {
      Quickshell.execDetached(["notify-send", "-a", "Clock", "Missed: " + title, body])
      return
    }
    ringing = { title: title, body: body }
    ringUntil = Date.now() + ringMs
    ringSound.running = true
    ringNotice.running = false
    ringNotice.command = ["notify-send", "-a", "Clock", "-t", String(ringMs),
      "-A", "dismiss=Dismiss", "-A", "snooze=Snooze " + snoozeMinutes + " min", title, body]
    ringNotice.running = true
  }

  function dismiss() {
    if (!ringing) return
    ringing = null
    ringSound.running = false
    ringNotice.running = false
  }

  function snooze() {
    if (!ringing) return
    var title = ringing.title
    dismiss()
    addTimer(snoozeMinutes, title)
  }

  function tick() {
    var stamp = Date.now()
    now = stamp

    if (ringing && stamp >= ringUntil) dismiss()

    var fired = []
    if (timers.some(function(timer) { return timer.endsAt > 0 && timer.endsAt <= stamp })) {
      timers = timers.filter(function(timer) {
        if (!(timer.endsAt > 0 && timer.endsAt <= stamp)) return true
        fired.push({
          title: timer.label || "Timer done",
          body: Alarms.countdown(timer.total) + " timer finished",
          late: stamp - timer.endsAt
        })
        return false
      })
    }

    if (alarms.some(function(alarm) { return alarm.enabled && alarm.nextAt > 0 && alarm.nextAt <= stamp })) {
      alarms = alarms.map(function(alarm) {
        if (!(alarm.enabled && alarm.nextAt > 0 && alarm.nextAt <= stamp)) return alarm
        fired.push({
          title: alarm.label || "Alarm",
          body: Alarms.timeLabel(alarm.hour, alarm.minute),
          late: stamp - alarm.nextAt
        })
        // A one-off alarm switches itself off; a repeating one rolls on.
        if (alarm.days.length === 0) return Object.assign({}, alarm, { enabled: false, nextAt: 0 })
        return Object.assign({}, alarm, { nextAt: Alarms.nextOccurrence(alarm.hour, alarm.minute, alarm.days, stamp) })
      })
    }

    if (fired.length === 0) return
    for (var i = 0; i < fired.length; i++) due(fired[i].title, fired[i].body, fired[i].late)
    save()
  }

  // ---- Persistence.

  function save() {
    if (loaded) stateWrite.restart()
  }

  function load(raw) {
    var saved = null
    try { saved = JSON.parse(raw) } catch (e) { saved = null }
    var stamp = Date.now()
    var highest = 0

    if (saved && Array.isArray(saved.alarms)) {
      alarms = saved.alarms.filter(function(alarm) {
        return alarm && alarm.hour >= 0 && alarm.hour <= 23 && alarm.minute >= 0 && alarm.minute <= 59
      }).map(function(alarm) {
        var days = Alarms.cleanDays(alarm.days)
        var enabled = alarm.enabled === true
        highest = Math.max(highest, Number(alarm.id) || 0)
        return {
          id: Number(alarm.id) || 0, hour: Number(alarm.hour), minute: Number(alarm.minute),
          label: String(alarm.label || ""), days: days, enabled: enabled,
          // Kept as saved when armed, so tick() sees one that came due while
          // the shell was down.
          nextAt: enabled ? (Number(alarm.nextAt) || Alarms.nextOccurrence(Number(alarm.hour), Number(alarm.minute), days, stamp)) : 0
        }
      })
    }

    if (saved && Array.isArray(saved.timers)) {
      timers = saved.timers.filter(function(timer) {
        return timer && Number(timer.total) > 0 && (Number(timer.endsAt) > 0 || Number(timer.pausedRemaining) > 0)
      }).map(function(timer) {
        highest = Math.max(highest, Number(timer.id) || 0)
        return {
          id: Number(timer.id) || 0, label: String(timer.label || ""), total: Number(timer.total),
          endsAt: Number(timer.endsAt) || 0, pausedRemaining: Number(timer.pausedRemaining) || 0
        }
      })
    }

    nextId = Math.max(highest + 1, saved ? Number(saved.nextId) || 1 : 1)
    loaded = true
    tick()
  }

  Process {
    id: readProc
    running: true
    command: ["bash", "-c", "mkdir -p \"$1\"; cat \"$2\" 2>/dev/null; true", "--", root.dir, root.statePath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.load(text)
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.loaded && root.busy
    onTriggered: root.tick()
  }

  // Coalesce writes: one tick can touch both lists.
  Timer {
    id: stateWrite
    interval: 50
    onTriggered: Quickshell.execDetached(["bash", "-c",
      "mkdir -p \"$1\" && printf '%s\\n' \"$3\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"",
      "--", root.dir, root.statePath,
      JSON.stringify({ alarms: root.alarms, timers: root.timers, nextId: root.nextId })])
  }

  // The sound file is a few seconds long, so it is replayed until answered.
  Process {
    id: ringSound
    command: ["pw-play", root.soundFile]
    onExited: if (root.ringing) ringReplay.restart()
  }

  Timer {
    id: ringReplay
    interval: 600
    onTriggered: if (root.ringing) ringSound.running = true
  }

  // notify-send blocks until the notification is answered and prints the
  // chosen action.
  Process {
    id: ringNotice
    stdout: SplitParser {
      onRead: function(line) {
        var action = String(line).trim()
        if (action === "dismiss") root.dismiss()
        else if (action === "snooze") root.snooze()
      }
    }
  }

  IpcHandler {
    target: "aaditya.clock"

    function timer(minutes: string, label: string): string {
      return root.addTimer(Number(minutes), label) ? "ok" : "invalid minutes"
    }
    function alarm(time: string, label: string): string {
      var parsed = Alarms.parseTime(time)
      if (!parsed) return "invalid time"
      root.addAlarm(parsed.hour, parsed.minute, label, [])
      return Alarms.timeLabel(parsed.hour, parsed.minute)
    }
    function dismiss(): string { root.dismiss(); return "ok" }
    function snooze(): string { root.snooze(); return "ok" }
    function status(): string {
      return JSON.stringify({ now: Date.now(), ringing: root.ringing, alarms: root.alarms, timers: root.timers })
    }
  }
}
