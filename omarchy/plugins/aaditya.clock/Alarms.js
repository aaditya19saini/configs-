.pragma library

// Pure helpers for alarms and timers. Weekdays follow Date.getDay():
// 0 is Sunday, 6 is Saturday.

var DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var DAY_INITIALS = ["S", "M", "T", "W", "T", "F", "S"]

function pad2(value) {
  return value < 10 ? "0" + value : String(value)
}

// "7", "7:30", "0730", "7.30", "7:30pm" -> { hour, minute }, else null.
function parseTime(text) {
  var match = /^\s*(\d{1,2})(?:[:.\s]?(\d{2}))?\s*([ap])?m?\s*$/i.exec(String(text || ""))
  if (!match) return null
  var hour = Number(match[1])
  var minute = match[2] === undefined ? 0 : Number(match[2])
  var meridiem = match[3] ? match[3].toLowerCase() : ""
  if (meridiem) {
    if (hour < 1 || hour > 12) return null
    if (meridiem === "p" && hour < 12) hour += 12
    if (meridiem === "a" && hour === 12) hour = 0
  }
  if (hour > 23 || minute > 59) return null
  return { hour: hour, minute: minute }
}

// The next time the wall clock reads hour:minute on one of `days` (any day
// when empty), strictly after `now`. Milliseconds since the epoch.
function nextOccurrence(hour, minute, days, now) {
  for (var offset = 0; offset <= 7; offset++) {
    var candidate = new Date(now)
    candidate.setDate(candidate.getDate() + offset)
    candidate.setHours(hour, minute, 0, 0)
    if (candidate.getTime() <= now) continue
    if (!days || days.length === 0 || days.indexOf(candidate.getDay()) !== -1) return candidate.getTime()
  }
  return 0
}

function timeLabel(hour, minute) {
  return pad2(hour) + ":" + pad2(minute)
}

// "4:59", "1:02:03". Rounded up so a fresh five minute timer reads 5:00.
function countdown(ms) {
  var seconds = Math.max(0, Math.ceil(ms / 1000))
  var hours = Math.floor(seconds / 3600)
  var minutes = Math.floor((seconds % 3600) / 60)
  var rest = seconds % 60
  return hours > 0 ? hours + ":" + pad2(minutes) + ":" + pad2(rest) : minutes + ":" + pad2(rest)
}

// "in 7h 12m", "in 3m", "in under a minute".
function untilLabel(ms) {
  var minutes = Math.floor(Math.max(0, ms) / 60000)
  if (minutes < 1) return "in under a minute"
  var days = Math.floor(minutes / 1440)
  var hours = Math.floor((minutes % 1440) / 60)
  var rest = minutes % 60
  if (days > 0) return "in " + days + "d " + hours + "h"
  if (hours > 0) return "in " + hours + "h " + rest + "m"
  return "in " + rest + "m"
}

function repeatLabel(days) {
  if (!days || days.length === 0) return "Once"
  var sorted = days.slice().sort()
  var key = sorted.join("")
  if (key === "0123456") return "Every day"
  if (key === "12345") return "Weekdays"
  if (key === "06") return "Weekends"
  // Monday first, Sunday last, as it is read aloud.
  var ordered = sorted.filter(function(day) { return day !== 0 })
  if (sorted.indexOf(0) !== -1) ordered.push(0)
  return ordered.map(function(day) { return DAY_NAMES[day] }).join(" ")
}

function cleanDays(days) {
  var out = []
  if (!Array.isArray(days)) return out
  for (var i = 0; i < days.length; i++) {
    var day = Number(days[i])
    if (day >= 0 && day <= 6 && Math.floor(day) === day && out.indexOf(day) === -1) out.push(day)
  }
  return out.sort()
}
