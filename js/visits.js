// Site-wide visit counter (Abacus, a free hit-counter API). Counts one visit per browser
// session, skips local previews, and fills any [data-visits] element with the total.
(function () {
  var API = "https://abacus.jasoncameron.dev";
  var KEY = "eslamabid175-github-io/visits";
  var local = location.protocol === "file:" || /^(localhost|127\.)/.test(location.hostname);

  var counted = false;
  try { counted = sessionStorage.getItem("visit-counted") === "1"; } catch (e) {}
  var action = local || counted ? "get" : "hit";

  fetch(API + "/" + action + "/" + KEY)
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (data) {
      if (!data || typeof data.value !== "number" || data.value < 0) return;
      if (action === "hit") {
        try { sessionStorage.setItem("visit-counted", "1"); } catch (e) {}
      }
      document.querySelectorAll("[data-visits]").forEach(function (el) {
        el.querySelector("[data-visits-value]").textContent = data.value.toLocaleString("en-US");
        el.hidden = false;
      });
    })
    .catch(function () {});
})();
