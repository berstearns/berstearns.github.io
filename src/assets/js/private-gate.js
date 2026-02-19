(function () {
  var code = document.querySelector('meta[name="private-code"]');
  if (!code) return;

  var expected = code.getAttribute("content");
  var key = "private-unlocked:" + location.pathname;

  // Already unlocked this session
  if (sessionStorage.getItem(key) === "1") return;

  // Hide page content immediately
  var content = document.querySelector(".md-content");
  if (content) content.style.display = "none";

  // Build overlay
  var overlay = document.createElement("div");
  overlay.className = "private-gate";
  overlay.innerHTML =
    '<div class="private-gate__box">' +
      '<div class="private-gate__icon">\uD83D\uDD12</div>' +
      '<p class="private-gate__label">This post is private</p>' +
      '<input class="private-gate__input" type="password" placeholder="Enter access code" autofocus>' +
      '<button class="private-gate__btn">Unlock</button>' +
    '</div>';

  document.body.appendChild(overlay);

  var input = overlay.querySelector(".private-gate__input");
  var btn = overlay.querySelector(".private-gate__btn");
  var box = overlay.querySelector(".private-gate__box");

  function attempt() {
    if (input.value === expected) {
      sessionStorage.setItem(key, "1");
      overlay.remove();
      if (content) content.style.display = "";
    } else {
      box.classList.remove("private-gate__shake");
      // Force reflow to restart animation
      void box.offsetWidth;
      box.classList.add("private-gate__shake");
      input.value = "";
      input.focus();
    }
  }

  btn.addEventListener("click", attempt);
  input.addEventListener("keydown", function (e) {
    if (e.key === "Enter") attempt();
  });
})();
