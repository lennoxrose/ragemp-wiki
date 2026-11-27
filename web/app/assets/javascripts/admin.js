// Keeps the Sync page live while a run is active: progress, counters and the log refresh every 2 seconds.
(function () {
  "use strict";
  var card = document.getElementById("run-card");
  if (!card || card.dataset.active !== "true") return;

  var win = document.getElementById("log-window"), list = document.getElementById("log-lines"), count = document.getElementById("log-count");
  var url = card.dataset.pollUrl, timer;

  function text(id, v) { var el = document.getElementById(id); if (el) el.textContent = v; }
  function fmt(n) { return Number(n).toLocaleString("en-US"); }

  function renderLines(lines) {
    var stick = win.scrollTop + win.clientHeight >= win.scrollHeight - 40;
    list.textContent = "";
    lines.forEach(function (l, i) {
      var li = document.createElement("li"); li.className = "lvl-" + String(l.level || "").toLowerCase();
      [["no", String(i + 1), "span"], ["time", l.time, "time"], ["level", l.level, "span"], ["msg", l.message, "span"]].forEach(function (p) {
        var e = document.createElement(p[2]); if (p[0] !== "time") e.className = p[0]; e.textContent = p[1] || ""; li.appendChild(e);
      });
      list.appendChild(li);
    });
    count.textContent = lines.length + " lines";
    if (stick) win.scrollTop = win.scrollHeight;
  }

  function poll() {
    fetch(url, { credentials: "same-origin", headers: { Accept: "application/json" } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) {
        if (!data || !data.run) return;
        var r = data.run;
        text("sync-listed", fmt(r.listed)); text("sync-changed", fmt(r.changed)); text("sync-removed", r.removed); text("sync-failed", r.failed);
        text("sync-percent-text", r.percent + "%"); text("sync-batches", "Batch " + r.batches + " · " + r.changed + " changed pages");
        var bar = document.getElementById("sync-bar"); if (bar) bar.style.width = r.percent + "%";
        renderLines(r.lines || []);
        if (!r.active) { clearInterval(timer); window.location.reload(); }
      })
      .catch(function () { /* keep trying */ });
  }
  win.scrollTop = win.scrollHeight;
  timer = setInterval(poll, 2000);
})();
