// The wiki map: every page is a dot, every link between pages is a line, category hubs gather their pages.
// Scroll to zoom, drag the background to pan, drag a dot to move it, click a dot to highlight what it links to,
// click it again (or double-click) to open the page.
(function () {
  "use strict";
  var stage = document.getElementById("map-stage");
  if (!stage || !window.d3) return;

  var cv = document.getElementById("map-canvas"), ctx = cv.getContext("2d");
  var statusEl = document.getElementById("map-status"), hintEl = document.getElementById("map-hint");
  var searchEl = document.getElementById("map-search"), resultsEl = document.getElementById("map-results"), chipsEl = document.getElementById("map-chips");
  var WIKI = stage.dataset.wikiBase, CATS_URL = stage.dataset.categoryBase;

  var cats = [], nodes = [], simLinks = [], adj = [], pageCount = 0;
  var transform = d3.zoomIdentity, W = 0, H = 0, dpr = 1, dirty = true;
  var hover = null, selected = null, matchSet = null, sim = null, sel = null, zoom = null, ready = false, hintTimer;
  var css = getComputedStyle(document.documentElement);
  var color = function (n) { return css.getPropertyValue(n).trim() || "#ffffff"; };
  var theme = { bg: "#0e0e0e", edge: "rgba(255,255,255,0.07)", hubEdge: "rgba(255,255,255,0.035)", accent: color("--accent"), text: color("--text"), halo: "rgba(14,14,14,0.85)", raised: color("--raised"), font: color("--font") };

  function fail(msg) { statusEl.hidden = false; statusEl.textContent = msg; }

  fetch(stage.dataset.graphUrl, { credentials: "same-origin", headers: { Accept: "application/json" } })
    .then(function (r) { if (!r.ok) throw new Error("HTTP " + r.status); return r.json(); })
    .then(build)
    .catch(function (e) { fail("The map could not be loaded (" + e.message + "). Reload the page to try again."); });

  /* ------------------------------------------------------------ data */
  function build(data) {
    cats = data.categories;
    var focusSlug = stage.dataset.focus, localMode = stage.dataset.local === "1";
    var all = data.nodes.map(function (n, i) { return { i: i, title: n[0], slug: n[0].replace(/ /g, "_"), cat: n[1], deg: n[2], hub: false }; });
    var pairs = data.links, keep = null;

    // local graph: only the focused page and the pages within two links of it
    if (localMode && focusSlug) {
      var focus = all.filter(function (n) { return n.slug === focusSlug; })[0];
      if (focus) {
        var nb = all.map(function () { return []; });
        for (var k = 0; k < pairs.length; k += 2) { nb[pairs[k]].push(pairs[k + 1]); nb[pairs[k + 1]].push(pairs[k]); }
        keep = new Set([focus.i]);
        var frontier = [focus.i];
        for (var d = 0; d < 2; d++) { var next = []; frontier.forEach(function (i) { nb[i].forEach(function (j) { if (!keep.has(j)) { keep.add(j); next.push(j); } }); }); frontier = next; }
      }
    }

    var remap = {};
    nodes = [];
    all.forEach(function (n) { if (!keep || keep.has(n.i)) { remap[n.i] = nodes.length; n.i = nodes.length; nodes.push(n); } });
    pageCount = nodes.length;
    simLinks = [];
    adj = nodes.map(function () { return []; });
    for (var p = 0; p < pairs.length; p += 2) {
      var a = remap[pairs[p]], b = remap[pairs[p + 1]];
      if (a === undefined || b === undefined) continue;
      simLinks.push({ source: nodes[a], target: nodes[b], kind: 0 });
      adj[a].push(b); adj[b].push(a);
    }

    // category hubs (not in the local graph): one dot per category that every page of it links to
    if (!keep) {
      var order = cats.map(function (c, ci) { return ci; });
      cats.forEach(function (c, ci) {
        var ang = (ci / cats.length) * Math.PI * 2, rad = 160 + 22 * Math.sqrt(order.length) * 6;
        var hub = { i: nodes.length, title: c.name, slug: c.name, cat: ci, deg: c.count, hub: true, x: Math.cos(ang) * rad * (ci === 0 ? 0.15 : 1), y: Math.sin(ang) * rad * (ci === 0 ? 0.15 : 1) };
        nodes.push(hub); adj.push([]);
      });
      for (var i = 0; i < pageCount; i++) { var hn = nodes[pageCount + nodes[i].cat]; simLinks.push({ source: nodes[i], target: hn, kind: 1 }); adj[hn.i].push(i); }
    }
    nodes.forEach(function (n) { n.color = cats[n.cat] ? cats[n.cat].color : "#b3aea2"; });

    // start near the hubs so the layout settles quickly
    nodes.forEach(function (n) {
      if (n.hub) return;
      var h = keep ? null : nodes[pageCount + n.cat];
      var r = 14 * Math.sqrt(Math.random()) * (keep ? 10 : 6) , t = Math.random() * 6.2832;
      n.x = (h ? h.x : 0) + Math.cos(t) * r; n.y = (h ? h.y : 0) + Math.sin(t) * r;
    });

    addChips(keep ? keep.size + " pages" : pageCount.toLocaleString("en-US") + " pages", simLinks.filter(function (l) { return l.kind === 0; }).length.toLocaleString("en-US") + " links", keep ? "local graph" : cats.length + " groups");
    setup();
    layout(keep ? 220 : 140, function () {
      var f = focusSlug && nodes.filter(function (n) { return !n.hub && n.slug === focusSlug; })[0];
      fit(null, false);
      if (f) { select(f, false); if (!keep) goTo(f, 3); }
    });
  }

  function addChips() {
    chipsEl.textContent = "";
    [].forEach.call(arguments, function (t) { var s = document.createElement("span"); s.className = "chip"; s.textContent = t; chipsEl.appendChild(s); });
  }

  /* --------------------------------------------------------- physics */
  function radiusOf(n) { return n.hub ? 6.5 : 1.5 + Math.min(2.4, Math.sqrt(n.deg) * 0.3); }
  function screenR(n) { return radiusOf(n) / Math.pow(transform.k, 0.42); }

  function layout(ticks, done) {
    sim = d3.forceSimulation(nodes).alphaDecay(0.035).velocityDecay(0.4).stop();
    sim.force("link", d3.forceLink(simLinks).strength(function (l) { return l.kind === 1 ? 0.22 : 0.02; }).distance(function (l) { return l.kind === 1 ? 26 : 64; }))
       .force("charge", d3.forceManyBody().strength(function (n) { return n.hub ? -420 : -7; }).theta(1).distanceMax(240))
       .force("x", d3.forceX(0).strength(0.012)).force("y", d3.forceY(0).strength(0.012));
    var count = 0;
    (function step() {
      var t0 = performance.now();
      while (performance.now() - t0 < 14 && count < ticks) { sim.tick(); count++; }
      if (count < ticks) { statusEl.hidden = false; statusEl.textContent = "Laying out the map… " + Math.round(count * 100 / ticks) + "%"; dirty = true; requestAnimationFrame(step); return; }
      statusEl.hidden = true; ready = true; done();
      sim.on("tick", function () { dirty = true; }).alpha(0.04).restart();
    })();
  }

  /* ------------------------------------------------------- rendering */
  function resize() {
    var r = stage.getBoundingClientRect(); dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = Math.max(1, r.width); H = Math.max(1, r.height);
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr); dirty = true;
  }
  function neighborSet(n) { var s = new Set(adj[n.i]); s.add(n.i); return s; }

  function draw() {
    dirty = false;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = theme.bg; ctx.fillRect(0, 0, W, H);
    if (!nodes.length) return;
    ctx.save(); ctx.translate(transform.x, transform.y); ctx.scale(transform.k, transform.k);
    var k = transform.k, active = hover || selected, nb = active ? neighborSet(active) : null;
    var x0 = -transform.x / k - 20, y0 = -transform.y / k - 20, x1 = (W - transform.x) / k + 20, y1 = (H - transform.y) / k + 20;
    function inView(n) { return n.x > x0 && n.x < x1 && n.y > y0 && n.y < y1; }

    // lines: category lines fainter than page-to-page links
    ctx.lineWidth = 0.55 / Math.pow(k, 0.55);
    [1, 0].forEach(function (kind) {
      ctx.strokeStyle = active ? "rgba(255,255,255,0.025)" : (kind === 1 ? theme.hubEdge : theme.edge);
      ctx.beginPath();
      for (var i = 0; i < simLinks.length; i++) {
        var l = simLinks[i]; if (l.kind !== kind) continue;
        var a = l.source, b = l.target;
        if ((a.x < x0 && b.x < x0) || (a.x > x1 && b.x > x1) || (a.y < y0 && b.y < y0) || (a.y > y1 && b.y > y1)) continue;
        if (active && (a === active || b === active)) continue;
        ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y);
      }
      ctx.stroke();
    });
    if (active) {
      ctx.strokeStyle = theme.accent; ctx.globalAlpha = 0.9; ctx.lineWidth = Math.max(1.1, 1.6 / Math.pow(k, 0.6)); ctx.beginPath();
      adj[active.i].forEach(function (j) { var o = nodes[j]; ctx.moveTo(active.x, active.y); ctx.lineTo(o.x, o.y); });
      ctx.stroke(); ctx.globalAlpha = 1;
    }

    // dots, batched per category: dimmed ones first, then the bright ones
    function paint(filter, alpha) {
      for (var c = 0; c < cats.length; c++) {
        ctx.fillStyle = cats[c].color; ctx.globalAlpha = alpha; ctx.beginPath();
        for (var i = 0; i < pageCount; i++) {
          var n = nodes[i]; if (n.cat !== c || !inView(n) || !filter(n)) continue;
          var r = screenR(n); ctx.moveTo(n.x + r, n.y); ctx.arc(n.x, n.y, r, 0, 6.2832);
        }
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    }
    if (matchSet) { paint(function (n) { return !matchSet.has(n.i); }, 0.12); paint(function (n) { return matchSet.has(n.i); }, 1); }
    else if (nb) { paint(function (n) { return !nb.has(n.i); }, 0.15); paint(function (n) { return nb.has(n.i); }, 1); }
    else paint(function () { return true; }, 0.9);

    for (var h = pageCount; h < nodes.length; h++) {
      var hn = nodes[h], r2 = screenR(hn), dim = (nb && !nb.has(hn.i)) || matchSet;
      ctx.globalAlpha = dim ? 0.3 : 1; ctx.fillStyle = theme.raised; ctx.beginPath(); ctx.arc(hn.x, hn.y, r2 * 1.9, 0, 6.2832); ctx.fill();
      ctx.fillStyle = theme.accent; ctx.beginPath(); ctx.arc(hn.x, hn.y, r2, 0, 6.2832); ctx.fill(); ctx.globalAlpha = 1;
    }
    if (selected) {
      var sr = screenR(selected); ctx.strokeStyle = theme.accent; ctx.globalAlpha = 0.45; ctx.lineWidth = 2 / Math.pow(k, 0.8);
      ctx.beginPath(); ctx.arc(selected.x, selected.y, sr * 2.6 + 3 / k, 0, 6.2832); ctx.stroke(); ctx.globalAlpha = 1;
      ctx.fillStyle = theme.accent; ctx.beginPath(); ctx.arc(selected.x, selected.y, sr * 1.3, 0, 6.2832); ctx.fill();
    }

    // labels at a constant size on screen
    var fs = 12 / k; ctx.font = "700 " + fs + "px " + theme.font; ctx.textBaseline = "middle";
    function label(n, bright) {
      var w = ctx.measureText(n.title).width, x = n.x + screenR(n) * 2 + 4 / k, y = n.y;
      ctx.fillStyle = theme.halo; ctx.fillRect(x - 3 / k, y - fs * 0.75, w + 6 / k, fs * 1.5);
      ctx.fillStyle = bright ? theme.accent : theme.text; ctx.fillText(n.title, x, y);
    }
    for (var q = pageCount; q < nodes.length; q++) if (inView(nodes[q])) label(nodes[q], false);
    if (k >= 2.4) {
      var shown = 0;
      for (var m = 0; m < pageCount && shown < 120; m++) {
        var pn = nodes[m]; if (!inView(pn) || pn === selected || pn === hover) continue;
        if (nb && !nb.has(pn.i)) continue; if (matchSet && !matchSet.has(pn.i)) continue;
        label(pn, false); shown++;
      }
    }
    if (selected && selected !== hover) label(selected, true);
    if (hover) label(hover, true);
    ctx.restore();
  }
  (function loop() { if (dirty) draw(); requestAnimationFrame(loop); })();

  /* ------------------------------------------- zoom, drag, interaction */
  function nodeAtEvent(e) {
    if (!sim) return null;
    var p = d3.pointer(e, cv), n = sim.find(transform.invertX(p[0]), transform.invertY(p[1]), 11 / transform.k);
    return n || null;
  }
  function setup() {
    resize(); new ResizeObserver(resize).observe(stage);
    zoom = d3.zoom().scaleExtent([0.08, 16]).filter(function (e) {
      if (e.type === "wheel") return true;
      if (e.ctrlKey || e.button) return false;
      return !((e.type === "mousedown" || e.type === "touchstart") && nodeAtEvent(e));
    }).on("start", function (e) { if (e.sourceEvent && e.sourceEvent.type === "mousedown") cv.classList.add("is-panning"); })
      .on("zoom", function (e) { transform = e.transform; dirty = true; })
      .on("end", function () { cv.classList.remove("is-panning"); });
    sel = d3.select(cv).call(zoom).on("dblclick.zoom", null);
    sel.call(d3.drag().clickDistance(4).container(cv)
      .subject(function (e) { var n = nodeAtEvent(e); return n ? { x: transform.applyX(n.x), y: transform.applyY(n.y), n: n } : null; })
      .on("start", function (e) { if (!e.active) sim.alphaTarget(0.25).restart(); e.subject.n.fx = e.subject.n.x; e.subject.n.fy = e.subject.n.y; })
      .on("drag", function (e) { e.subject.n.fx = transform.invertX(e.x); e.subject.n.fy = transform.invertY(e.y); dirty = true; })
      .on("end", function (e) { if (!e.active) sim.alphaTarget(0); e.subject.n.fx = null; e.subject.n.fy = null; }));

    cv.addEventListener("pointermove", function (e) {
      if (e.buttons || !ready) return;
      var n = nodeAtEvent(e); if (n !== hover) { hover = n; cv.classList.toggle("is-hover", !!n); dirty = true; }
    });
    cv.addEventListener("pointerleave", function () { if (hover) { hover = null; cv.classList.remove("is-hover"); dirty = true; } });
    cv.addEventListener("click", function (e) {
      var n = nodeAtEvent(e);
      if (!n) { selected = null; hint(null); dirty = true; return; }
      if (n === selected) return open(n);
      select(n, false);
    });
    cv.addEventListener("dblclick", function (e) { var n = nodeAtEvent(e); if (n) open(n); });

    document.getElementById("zoom-in").onclick = function () { sel.transition().duration(220).call(zoom.scaleBy, 1.6); };
    document.getElementById("zoom-out").onclick = function () { sel.transition().duration(220).call(zoom.scaleBy, 1 / 1.6); };
    document.getElementById("zoom-fit").onclick = function () { fit(null, true); };
    document.addEventListener("keydown", function (e) {
      if (/INPUT|TEXTAREA|SELECT/.test((e.target || {}).tagName || "")) return;
      if (e.key === "+" || e.key === "=") document.getElementById("zoom-in").click();
      else if (e.key === "-") document.getElementById("zoom-out").click();
      else if (e.key === "0") document.getElementById("zoom-fit").click();
      else if (e.key === "Escape") { selected = null; hint(null); dirty = true; }
    });
  }

  function select(n, zoomTo) {
    selected = n; dirty = true;
    hint(n.hub ? n.title + " · " + n.deg.toLocaleString("en-US") + " pages. Click again to open the category." : n.title + " · " + cats[n.cat].name + " · " + adj[n.i].length + " links. Click again to open the page.");
    if (zoomTo) goTo(n, 2.6);
  }
  function open(n) { window.location.href = n.hub ? CATS_URL + encodeURIComponent(n.title) : WIKI + encodeURIComponent(n.slug); }
  function hint(text) {
    clearTimeout(hintTimer);
    if (!text) { hintEl.hidden = true; return; }
    hintEl.textContent = text; hintEl.hidden = false;
    hintTimer = setTimeout(function () { hintEl.hidden = true; }, 6000);
  }
  function goTo(n, k) {
    var kk = Math.max(transform.k, k || 2.4);
    sel.transition().duration(650).call(zoom.transform, d3.zoomIdentity.translate(W / 2, H / 2).scale(kk).translate(-n.x, -n.y));
  }
  function fit(list, animate) {
    var pts = list || nodes; if (!pts.length) return;
    var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    if (pts.length > 200) { // ignore the outermost 1% so a few drifting dots do not zoom the whole map out
      var xs = pts.map(function (n) { return n.x; }).sort(function (a, b) { return a - b; }), ys = pts.map(function (n) { return n.y; }).sort(function (a, b) { return a - b; });
      var lo = Math.floor(pts.length * 0.01), hi = Math.ceil(pts.length * 0.99) - 1;
      x0 = xs[lo]; x1 = xs[hi]; y0 = ys[lo]; y1 = ys[hi];
    } else {
      pts.forEach(function (n) { if (n.x < x0) x0 = n.x; if (n.x > x1) x1 = n.x; if (n.y < y0) y0 = n.y; if (n.y > y1) y1 = n.y; });
    }
    var w = Math.max(60, x1 - x0), h = Math.max(60, y1 - y0), k = Math.min(W / (w + 120), H / (h + 120), 6);
    var t = d3.zoomIdentity.translate(W / 2, H / 2).scale(k).translate(-(x0 + x1) / 2, -(y0 + y1) / 2);
    if (animate) sel.transition().duration(650).call(zoom.transform, t); else sel.call(zoom.transform, t);
  }

  /* ------------------------------------------------------------ search */
  var active = -1;
  function setMatches(text) {
    text = text.trim().toLowerCase(); resultsEl.textContent = ""; active = -1;
    if (!text) { matchSet = null; resultsEl.hidden = true; dirty = true; return; }
    var m = [];
    for (var i = 0; i < pageCount; i++) if (nodes[i].title.toLowerCase().indexOf(text) >= 0) m.push(nodes[i]);
    matchSet = new Set(m.map(function (n) { return n.i; })); dirty = true;
    m.sort(function (a, b) { return (a.title.toLowerCase().indexOf(text) - b.title.toLowerCase().indexOf(text)) || (b.deg - a.deg); }).slice(0, 8).forEach(function (n) {
      var li = document.createElement("li"), b = document.createElement("button"); b.type = "button";
      var d = document.createElement("span"); d.className = "dot"; d.style.background = n.color;
      var s = document.createElement("span"); s.textContent = n.title; var c = document.createElement("span"); c.className = "cat"; c.textContent = cats[n.cat].name;
      b.appendChild(d); b.appendChild(s); b.appendChild(c); b.onclick = function () { choose(n); }; li.appendChild(b); resultsEl.appendChild(li);
    });
    if (!m.length) { var li = document.createElement("li"); li.className = "hint"; li.textContent = "No pages match."; resultsEl.appendChild(li); }
    resultsEl.hidden = false;
  }
  function choose(n) { searchEl.value = n.title; resultsEl.hidden = true; matchSet = null; select(n, true); }
  searchEl.addEventListener("input", function () { if (ready) setMatches(searchEl.value); });
  searchEl.addEventListener("keydown", function (e) {
    var items = resultsEl.querySelectorAll("button");
    if (e.key === "ArrowDown" || e.key === "ArrowUp") { e.preventDefault(); if (!items.length) return; active = (active + (e.key === "ArrowDown" ? 1 : -1) + items.length) % items.length; items.forEach(function (b, i) { b.setAttribute("aria-selected", String(i === active)); }); }
    else if (e.key === "Enter") { e.preventDefault(); var b = items[Math.max(active, 0)]; if (b) b.click(); }
    else if (e.key === "Escape") { searchEl.value = ""; setMatches(""); searchEl.blur(); }
  });
})();
