// Small enhancements; every page still works without JavaScript.
(function () {
  "use strict";

  // "/" focuses the search box
  document.addEventListener("keydown", function (e) {
    var t = e.target, typing = t && /INPUT|TEXTAREA|SELECT/.test(t.tagName);
    if (e.key === "/" && !typing && !e.metaKey && !e.ctrlKey) {
      var box = document.getElementById("site-search") || document.getElementById("map-search");
      if (box) { e.preventDefault(); box.focus(); }
    }
  });

  // forms with data-autosubmit send themselves when a choice changes (appearance settings)
  document.addEventListener("change", function (e) {
    var form = e.target.closest("form[data-autosubmit]");
    if (form) form.requestSubmit();
  });

  // copy buttons: <button data-copy="text"> or data-copy-target="#id"
  document.addEventListener("click", function (e) {
    var b = e.target.closest("[data-copy], [data-copy-target]");
    if (!b) return;
    var text = b.dataset.copy || (document.querySelector(b.dataset.copyTarget) || {}).textContent || "";
    var done = function () { var old = b.textContent; if (b.dataset.keep !== "1") { b.textContent = "Copied"; setTimeout(function () { b.textContent = old; }, 1500); } };
    if (navigator.clipboard) navigator.clipboard.writeText(text.trim()).then(done, function () {});
  });

  // dialogs: <button data-open="dialog-id"> and <button data-close>
  document.addEventListener("click", function (e) {
    var o = e.target.closest("[data-open]");
    if (o) { var d = document.getElementById(o.dataset.open); if (d && d.showModal) d.showModal(); }
    var c = e.target.closest("[data-close]");
    if (c) { var dlg = c.closest("dialog"); if (dlg) dlg.close(); }
  });
  Array.prototype.forEach.call(document.querySelectorAll("dialog[data-open-on-load]"), function (d) { if (d.showModal) d.showModal(); });

  // toggle switches inside forms keep a hidden input in sync: <button class="toggle" data-toggle-input="#id">
  document.addEventListener("click", function (e) {
    var t = e.target.closest("button.toggle[data-toggle-input]");
    if (!t) return;
    var on = t.getAttribute("aria-checked") !== "true";
    t.setAttribute("aria-checked", String(on));
    var input = document.querySelector(t.dataset.toggleInput);
    if (input) input.value = on ? "1" : "0";
    if (t.closest("form[data-autosubmit]")) t.closest("form").requestSubmit();
  });
})();
