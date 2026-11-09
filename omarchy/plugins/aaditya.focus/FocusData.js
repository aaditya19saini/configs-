.pragma library

var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

function pad(n) { return n < 10 ? "0" + n : String(n) }

function dayKey(date) {
  return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
}

function parseLog(text) {
  var lines = String(text || "").split("\n")
  var entries = []
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i]) continue
    var entry
    try { entry = JSON.parse(lines[i]) } catch (e) { continue }
    if (!entry || !(Number(entry.end) > Number(entry.start))) continue
    entries.push({ start: Number(entry.start), end: Number(entry.end), name: String(entry.name || "") })
  }
  return entries
}

// Fold focused stretches into { "YYYY-MM-DD": { seconds, names[] } }. A stretch
// that runs past midnight is split so each day gets only its own share.
function aggregate(entries, live) {
  var days = ({})
  var all = live ? entries.concat([live]) : entries
  for (var i = 0; i < all.length; i++) {
    var cursor = all[i].start
    var end = all[i].end
    var name = all[i].name
    while (cursor < end) {
      var date = new Date(cursor)
      var midnight = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime()
      var stop = Math.min(end, midnight)
      var key = dayKey(date)
      var day = days[key] || (days[key] = { seconds: 0, names: [] })
      day.seconds += (stop - cursor) / 1000
      if (name && day.names.indexOf(name) === -1) day.names.push(name)
      cursor = stop
    }
  }
  return days
}

// Columns of weeks (Sunday first), the last column being the current week.
function grid(weeks, todayMs) {
  var today = new Date(todayMs)
  var todayKey = dayKey(today)
  var columns = []
  var lastMonth = -1
  for (var w = weeks - 1; w >= 0; w--) {
    var cells = []
    var label = ""
    for (var d = 0; d < 7; d++) {
      var date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - today.getDay() - w * 7 + d)
      var key = dayKey(date)
      cells.push({ key: key, time: date.getTime(), future: key > todayKey })
      if (d === 0 && date.getMonth() !== lastMonth) {
        if (lastMonth !== -1) label = MONTHS[date.getMonth()]
        lastMonth = date.getMonth()
      }
    }
    columns.push({ cells: cells, label: label })
  }
  return columns
}

function level(seconds) {
  if (!(seconds >= 60)) return 0
  if (seconds < 30 * 60) return 1
  if (seconds < 60 * 60) return 2
  if (seconds < 120 * 60) return 3
  return 4
}

function secondsOn(days, key) {
  return days && days[key] ? days[key].seconds : 0
}

// Consecutive days with focused time, ending today (or yesterday while today
// is still empty, so the streak does not read as broken every morning).
function streak(days, todayMs) {
  var today = new Date(todayMs)
  var count = 0
  for (var back = 0; back < 3660; back++) {
    var key = dayKey(new Date(today.getFullYear(), today.getMonth(), today.getDate() - back))
    if (secondsOn(days, key) >= 60) count++
    else if (back > 0) break
  }
  return count
}

function duration(seconds) {
  var minutes = Math.floor((Number(seconds) || 0) / 60)
  if (minutes < 60) return minutes + "m"
  return Math.floor(minutes / 60) + "h " + pad(minutes % 60) + "m"
}

function clock(ms) {
  var seconds = Math.max(0, Math.ceil((Number(ms) || 0) / 1000))
  var hours = Math.floor(seconds / 3600)
  var rest = pad(Math.floor((seconds % 3600) / 60)) + ":" + pad(seconds % 60)
  return hours > 0 ? hours + ":" + rest : rest
}

function describeDay(days, cell) {
  var date = new Date(cell.time)
  var text = WEEKDAYS[date.getDay()] + " " + date.getDate() + " " + MONTHS[date.getMonth()] + "  ·  "
  var day = days ? days[cell.key] : null
  if (!day || day.seconds < 60) return text + "no focus"
  return text + duration(day.seconds) + (day.names.length ? "  ·  " + day.names.join(", ") : "")
}
